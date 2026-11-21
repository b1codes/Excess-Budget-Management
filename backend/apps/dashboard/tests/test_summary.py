import pytest

pytestmark = pytest.mark.django_db

ZERO = {
    "total_balance": "0.00",
    "goals_total_target": "0.00",
    "goals_total_current": "0.00",
    "budgets_total_limit": "0.00",
    "budgets_total_spent": "0.00",
}


def test_empty_summary_is_all_zero(api):
    assert api.get("/dashboard/summary").json() == ZERO


def test_summary_only_counts_own_data(api, other_api, make):
    theirs = make.as_(other_api)
    theirs.account(balance="999.00")
    theirs.goal(target_amount="999.00")
    theirs.category(limit_amount="999.00")
    assert make.get("/dashboard/summary") == ZERO


def test_summary_tracks_live_rollups(api, make):
    account = make.account(balance="100.00")
    make.account(balance="0.10")
    category = make.category(limit_amount="300.00")
    goal = make.goal(target_amount="1000.00")
    make.expense(category["id"], amount="20.00", account_id=account["id"])
    make.allocation(goal["id"], amount="30.00", account_id=account["id"])

    assert make.get("/dashboard/summary") == {
        "total_balance": "50.10",
        "goals_total_target": "1000.00",
        "goals_total_current": "30.00",
        "budgets_total_limit": "300.00",
        "budgets_total_spent": "20.00",
    }


def test_budget_totals_leave_out_income_categories(api, make):
    # Regression: income categories were summed in too, so an income target
    # counted as budget and income received counted as money spent (found
    # by the E2E suite, where $250 of income showed as $250 spent).
    groceries = make.category(limit_amount="300.00")
    side_gigs = make.category(name="Side gigs", limit_amount="500.00", category_type="income")
    make.expense(groceries["id"], amount="20.00")
    make.extra_income(amount="250.00", budget_category_id=side_gigs["id"])

    summary = make.get("/dashboard/summary")

    assert summary["budgets_total_limit"] == "300.00"
    assert summary["budgets_total_spent"] == "20.00"
