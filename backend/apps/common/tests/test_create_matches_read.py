"""A create response must be exactly what a GET of the new resource returns.

Regression: create endpoints used to echo request amounts verbatim ("5"),
while reads go through the cents round trip ("5.00").
"""

import pytest

from apps.common.money import normalize

pytestmark = pytest.mark.django_db


@pytest.fixture
def parents(make):
    return {"category": make.category(), "goal": make.goal(), "account": make.account()}


CASES = {
    "account": lambda p: ("/accounts", {"name": "A", "balance": "5"}),
    "account_default_balance": lambda p: ("/accounts", {"name": "A"}),
    "category": lambda p: ("/budget/categories", {"name": "C", "limit_amount": "5"}),
    "goal": lambda p: ("/goals", {"name": "G", "target_amount": "5", "type": "long_term"}),
    "expense": lambda p: (
        "/expenses",
        {"budget_category_id": p["category"]["id"], "amount": "5", "date": "2026-01-01"},
    ),
    "income_source": lambda p: (
        "/income/sources",
        {"name": "S", "expected_amount": "5", "frequency": "monthly"},
    ),
    "extra_income": lambda p: ("/income/extra", {"amount": "5.5", "date_received": "2026-01-01"}),
    "allocation": lambda p: ("/allocations", {"goal_id": p["goal"]["id"], "amount": "5"}),
}


@pytest.mark.parametrize("case", sorted(CASES))
def test_create_response_matches_get(api, make, parents, case):
    path, payload = CASES[case](parents)
    created = api.post(path, payload)
    assert created.status_code == 201, created.content
    assert created.json() == make.get(f"{path}/{created.json()['id']}")


def test_subgoal_create_response_matches_list(api, make, parents):
    goal_id = parents["goal"]["id"]
    created = api.post(
        f"/goals/{goal_id}/subgoals", {"name": "S", "target_amount": "5", "current_amount": "1"}
    ).json()
    # There's no single-subgoal GET route; the list is the read path.
    assert make.get(f"/goals/{goal_id}/subgoals") == [created]


@pytest.mark.parametrize(
    "raw,expected", [("5", "5.00"), ("5.5", "5.50"), ("0", "0.00"), ("-2", "-2.00")]
)
def test_normalize(raw, expected):
    from decimal import Decimal

    assert str(normalize(Decimal(raw))) == expected
