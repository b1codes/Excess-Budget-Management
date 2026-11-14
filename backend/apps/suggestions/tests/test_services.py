"""Suggestion generation: the Gemini client wrapper, the context and prompt
sent to it, and handling of what comes back. The live API is never called."""

import json
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest
from django.test import override_settings

from apps.common.exceptions import UpstreamError
from apps.common.firestore import get_client
from apps.suggestions import services
from apps.users.models import Profile

pytestmark = pytest.mark.django_db

GOOD = {"suggestions": [{"goalName": "Trip", "amount": 60.0}], "reasoning": "Because."}


def _audit_docs(user):
    return list(
        get_client().collection(services.COLLECTION).where("user_id", "==", str(user.id)).stream()
    )


# --- call_gemini ------------------------------------------------------------------


@override_settings(GEMINI_API_KEY="")
def test_call_gemini_without_key_is_an_upstream_error():
    with pytest.raises(UpstreamError, match="not configured"):
        services.call_gemini("prompt")


@override_settings(GEMINI_API_KEY="test-key")
def test_call_gemini_parses_json_response():
    fake_client = MagicMock()
    fake_client.models.generate_content.return_value = SimpleNamespace(text=json.dumps(GOOD))
    with patch("google.genai.Client", return_value=fake_client) as client_cls:
        assert services.call_gemini("the prompt") == GOOD

    client_cls.assert_called_once_with(api_key="test-key")
    kwargs = fake_client.models.generate_content.call_args.kwargs
    assert kwargs["contents"] == "the prompt"
    assert kwargs["config"] == {"response_mime_type": "application/json"}


@override_settings(GEMINI_API_KEY="test-key")
@pytest.mark.parametrize(
    "failure",
    [
        lambda c: setattr(c.models.generate_content, "side_effect", RuntimeError("quota")),
        lambda c: setattr(
            c.models.generate_content, "return_value", SimpleNamespace(text="not json")
        ),
    ],
    ids=["client_error", "non_json_body"],
)
def test_call_gemini_failures_are_upstream_errors(failure):
    fake_client = MagicMock()
    failure(fake_client)
    with patch("google.genai.Client", return_value=fake_client):
        with pytest.raises(UpstreamError, match="Gemini call failed"):
            services.call_gemini("prompt")


# --- Context and prompt -------------------------------------------------------------


def test_context_includes_goals_subgoals_accounts_and_ratio(user, make):
    Profile.objects.create(user=user, default_savings_ratio=Decimal("0.70"))
    goal = make.goal(name="Trip", category="purchase", target_date="2027-01-01")
    make.subgoal(goal["id"], name="Flights", target_amount="300.00", current_amount="20.00")
    make.account(name="Checking", balance="12.34")
    make.allocation(goal["id"], amount="5.00")

    ctx = services.gather_context(user)

    assert ctx["defaultSavingsRatio"] == 0.7
    assert ctx["accounts"] == [
        {"id": ctx["accounts"][0]["id"], "name": "Checking", "balance": 12.34}
    ]
    [g] = ctx["goals"]
    assert (g["name"], g["category"], g["target_date"]) == ("Trip", "purchase", "2027-01-01")
    # The allocation targets the goal itself, so the subgoal is unchanged.
    assert g["sub_goals"] == [{"name": "Flights", "target": 300.0, "current": 20.0}]
    assert ctx["recentAllocations"] == {"totalSavings": 0.0, "totalPurchases": 5.0}


def test_context_defaults_ratio_without_profile(user):
    assert services.gather_context(user)["defaultSavingsRatio"] == 0.5


def test_context_only_includes_own_data(user, make, other_api):
    theirs = make.as_(other_api)
    theirs.goal(name="Theirs")
    theirs.account(name="Theirs")
    ctx = services.gather_context(user)
    assert ctx["goals"] == [] and ctx["accounts"] == []


def test_prompt_mentions_excess_ratio_and_goals(user, make):
    make.goal(name="Trip")
    prompt = services._build_prompt(Decimal("250.00"), services.gather_context(user))
    assert "$250.00" in prompt
    assert "50% savings" in prompt
    assert "Trip" in prompt


# --- Endpoint -----------------------------------------------------------------------


def test_generate_persists_an_audit_record(api, user):
    with patch.object(services, "call_gemini", return_value=GOOD) as gemini:
        r = api.post("/suggestions/generate", {"excess_funds": "100.50"})

    assert r.status_code == 200
    assert r.json() == {
        "suggestions": [{"goalName": "Trip", "amount": 60.0, "subgoalName": None}],
        "reasoning": "Because.",
    }
    assert "$100.50" in gemini.call_args.args[0]
    [doc] = _audit_docs(user)
    assert doc.get("excess_funds") == 10050
    assert doc.get("response_json") == GOOD


@pytest.mark.parametrize(
    "bad",
    [
        {"reasoning": "no suggestions key"},
        {"suggestions": "not a list", "reasoning": "x"},
        {"suggestions": [{"amount": 1}], "reasoning": "missing goalName"},
        ["not", "an", "object"],
    ],
    ids=["missing_suggestions", "wrong_type", "bad_item", "array"],
)
def test_malformed_model_output_is_a_502_and_not_persisted(api, user, bad):
    # Regression: output that didn't match SuggestOut was saved, then failed
    # response validation and surfaced as a 500.
    with patch.object(services, "call_gemini", return_value=bad):
        r = api.post("/suggestions/generate", {"excess_funds": "100.00"})

    assert r.status_code == 502
    assert r.json()["error"]["code"] == "upstream_error"
    assert _audit_docs(user) == []


def test_upstream_failure_is_not_persisted(api, user):
    with patch.object(services, "call_gemini", side_effect=UpstreamError("down")):
        assert api.post("/suggestions/generate", {"excess_funds": "1.00"}).status_code == 502
    assert _audit_docs(user) == []


@pytest.mark.parametrize("payload", [{}, {"excess_funds": "x"}, {"excess_funds": "1.001"}])
def test_generate_validation(api, payload):
    with patch.object(services, "call_gemini") as gemini:
        assert api.post("/suggestions/generate", payload).status_code == 422
    gemini.assert_not_called()
