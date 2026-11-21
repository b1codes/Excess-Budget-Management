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

GOOD = {
    "allocations": [{"type": "goal", "id": "<goal>", "amount": 60.0, "reason": "Soonest"}],
    "reasoning": "Because.",
}


def _reply(*allocations, reasoning="Because."):
    return {"allocations": list(allocations), "reasoning": reasoning}


def _goal(id, amount, reason="r"):
    return {"type": "goal", "id": id, "amount": amount, "reason": reason}


def _account(id, amount, reason="r"):
    return {"type": "account", "id": id, "amount": amount, "reason": reason}


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


def _generate(api, reply, excess="100.00"):
    with patch.object(services, "call_gemini", return_value=reply) as gemini:
        r = api.post("/suggestions/generate", {"excess_funds": excess})
    return r, gemini


def test_generate_returns_the_apps_shape_and_persists_an_audit_record(api, user, make):
    goal = make.goal(name="Trip")
    account = make.account(name="Savings")
    reply = _reply(_goal(goal["id"], 60.0, "Soonest"), _account(account["id"], 15.5, "Buffer"))

    r, gemini = _generate(api, reply, excess="100.50")

    assert r.status_code == 200
    assert r.json() == {
        "allocations": [
            {
                "type": "goal",
                "id": goal["id"],
                "name": "Trip",
                "amount": "60.00",
                "reason": "Soonest",
            },
            {
                "type": "account",
                "id": account["id"],
                "name": "Savings",
                "amount": "15.50",
                "reason": "Buffer",
            },
        ],
        "totalAllocated": "75.50",
        "reasoning": "Because.",
    }
    prompt = gemini.call_args.args[0]
    assert "$100.50" in prompt
    assert goal["id"] in prompt and account["id"] in prompt
    [doc] = _audit_docs(user)
    assert doc.get("excess_funds") == 10050
    assert doc.get("response_json") == reply


def test_names_come_from_the_users_records(api, make):
    goal = make.goal(name="Real name")
    reply = _reply({**_goal(goal["id"], 10), "name": "Model's name"})
    assert _generate(api, reply)[0].json()["allocations"][0]["name"] == "Real name"


def test_ids_the_user_does_not_own_are_dropped(api, other_api, make):
    mine = make.goal(name="Mine")
    theirs = make.as_(other_api).goal(name="Theirs")
    their_account = make.as_(other_api).account()
    reply = _reply(
        _goal(mine["id"], 10),
        _goal(theirs["id"], 20),
        _account(their_account["id"], 30),
        _goal("not-a-real-id", 5),
        # Right id, wrong type: a goal id is not an account.
        _account(mine["id"], 5),
    )

    body = _generate(api, reply)[0].json()

    assert [a["id"] for a in body["allocations"]] == [mine["id"]]
    assert body["totalAllocated"] == "10.00"


def test_amounts_are_rounded_to_cents_and_sub_cent_ones_dropped(api, make):
    goal = make.goal()
    other = make.goal(name="Other")
    reply = _reply(_goal(goal["id"], 33.333333333333336), _goal(other["id"], 0.001))

    body = _generate(api, reply)[0].json()

    assert [(a["id"], a["amount"]) for a in body["allocations"]] == [(goal["id"], "33.33")]
    assert body["totalAllocated"] == "33.33"


def test_empty_suggestion_list_is_fine(api):
    r, _ = _generate(api, _reply())
    assert r.status_code == 200
    assert r.json() == {"allocations": [], "totalAllocated": "0.00", "reasoning": "Because."}


def test_allocating_more_than_the_excess_is_a_502_and_not_persisted(api, user, make):
    goal = make.goal()
    r, _ = _generate(api, _reply(_goal(goal["id"], 60), _goal(goal["id"], 41)), excess="100.00")

    assert r.status_code == 502
    assert r.json()["error"]["details"] == {"excess_funds": "100.00", "suggested": "101.00"}
    assert _audit_docs(user) == []


@pytest.mark.parametrize(
    "bad",
    [
        {"reasoning": "no allocations key"},
        {"allocations": "not a list", "reasoning": "x"},
        {"allocations": [{"type": "goal", "amount": 1}], "reasoning": "missing id"},
        {"allocations": [{"type": "fund", "id": "x", "amount": 1}], "reasoning": "bad type"},
        {"allocations": [{"type": "goal", "id": "x", "amount": -5}], "reasoning": "negative"},
        {"allocations": [{"type": "goal", "id": "x", "amount": 0}], "reasoning": "zero"},
        {"allocations": [], "reasoning": None},
        # The old reply shape, from before the API matched the app.
        {"suggestions": [{"goalName": "Trip", "amount": 1}], "reasoning": "x"},
        ["not", "an", "object"],
    ],
    ids=[
        "missing_allocations",
        "wrong_type",
        "missing_id",
        "unknown_target_type",
        "negative_amount",
        "zero_amount",
        "missing_reasoning",
        "old_shape",
        "array",
    ],
)
def test_malformed_model_output_is_a_502_and_not_persisted(api, user, bad):
    # Regression: output that didn't match the schema was saved, then failed
    # response validation and surfaced as a 500.
    r, _ = _generate(api, bad)

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
