"""Overtime settings and projection maths, including every branch of
calculate_overtime_projections."""

import pytest

pytestmark = pytest.mark.django_db

PROJECTIONS = "/income/overtime/projections"


@pytest.fixture
def rates(api):
    # net hourly = 50 * 1.5 * (1 - 0.2) = 60.00; monthly at 10h/wk = 2600.00
    api.patch(
        "/income/overtime/settings",
        {"hourly_base_rate": "50.00", "overtime_multiplier": "1.50", "estimated_tax_rate": "0.20"},
    )


def test_settings_are_created_lazily_per_user(api, other_api):
    api.patch("/income/overtime/settings", {"hourly_base_rate": "30.00"})
    assert other_api.get("/income/overtime/settings").json()["hourly_base_rate"] == "0.00"


def test_settings_patch_is_partial(api):
    api.patch("/income/overtime/settings", {"hourly_base_rate": "30.00"})
    body = api.patch("/income/overtime/settings", {"estimated_tax_rate": "0.30"}).json()
    assert body["hourly_base_rate"] == "30.00"
    assert body["overtime_multiplier"] == "1.50"
    assert body["estimated_tax_rate"] == "0.30"


def test_settings_patch_before_first_get_creates_defaults(api):
    body = api.patch("/income/overtime/settings", {"overtime_multiplier": "2.00"}).json()
    assert body["hourly_base_rate"] == "0.00" and body["overtime_multiplier"] == "2.00"


def test_settings_patch_bumps_updated_at_only(api):
    first = api.get("/income/overtime/settings").json()
    second = api.patch("/income/overtime/settings", {"hourly_base_rate": "1.00"}).json()
    assert second["created_at"] == first["created_at"]
    assert second["updated_at"] > first["updated_at"]


@pytest.mark.parametrize(
    "payload",
    [
        {"hourly_base_rate": "-1.00"},
        {"overtime_multiplier": "-1.00"},
        {"estimated_tax_rate": "-0.10"},
        {"estimated_tax_rate": "1.01"},
        {"overtime_multiplier": "100.00"},
    ],
    ids=["negative_rate", "negative_multiplier", "negative_tax", "tax_over_100pct", "huge_mult"],
)
def test_settings_validation(api, payload):
    assert api.patch("/income/overtime/settings", payload).status_code == 422


def test_projection_without_target_only_returns_income(api, rates):
    body = api.post(PROJECTIONS, {"overtime_hours_per_week": "10.00"}).json()
    assert body == {
        "net_hourly_rate": "60.00",
        "weekly_overtime_net_income": "600.00",
        "monthly_overtime_net_income": "2600.00",
        "total_hours_needed": None,
        "months_to_complete_standard": None,
        "months_to_complete_with_overtime": None,
        "months_saved": None,
    }


def test_projection_with_zero_rate_has_no_hours_or_overtime_months(api, make):
    goal = make.goal(target_amount="1000.00")
    body = api.post(PROJECTIONS, {"overtime_hours_per_week": "10.00", "goal_id": goal["id"]}).json()
    assert body["net_hourly_rate"] == "0.00"
    assert body["total_hours_needed"] is None
    assert body["months_to_complete_with_overtime"] is None


def test_projection_overtime_only(api, make, rates):
    goal = make.goal(target_amount="5200.00")
    body = api.post(PROJECTIONS, {"overtime_hours_per_week": "10.00", "goal_id": goal["id"]}).json()
    assert body["total_hours_needed"] == "86.67"
    assert body["months_to_complete_standard"] is None
    assert body["months_to_complete_with_overtime"] == "2.00"
    assert body["months_saved"] is None


def test_projection_for_a_funded_goal_is_zero(api, make, rates):
    account = make.account(balance="2000.00")
    goal = make.goal(target_amount="1000.00")
    api.post(f"/goals/{goal['id']}/accounts", {"account_id": account["id"]})

    body = api.post(
        PROJECTIONS,
        {"overtime_hours_per_week": "10.00", "goal_id": goal["id"], "standard_contribution": "100"},
    ).json()

    assert body["total_hours_needed"] == "0.00"
    assert body["months_to_complete_standard"] == "0.00"
    assert body["months_saved"] == "0.00"


def test_projection_for_subgoal_with_its_goal(api, make, rates):
    goal = make.goal()
    sub = make.subgoal(goal["id"], target_amount="600.00", current_amount="0.00")
    body = api.post(
        PROJECTIONS,
        {"overtime_hours_per_week": "10.00", "goal_id": goal["id"], "subgoal_id": sub["id"]},
    ).json()
    assert body["total_hours_needed"] == "10.00"


def test_projection_for_subgoal_with_the_wrong_goal_is_404(api, make, rates):
    sub = make.subgoal(make.goal(name="A")["id"])
    other_goal = make.goal(name="B")
    r = api.post(
        PROJECTIONS,
        {"overtime_hours_per_week": "1.00", "goal_id": other_goal["id"], "subgoal_id": sub["id"]},
    )
    assert r.status_code == 404


def test_projection_for_another_users_subgoal_is_404(api, other_api, make, rates):
    theirs = make.as_(other_api)
    sub = theirs.subgoal(theirs.goal()["id"])
    r = api.post(PROJECTIONS, {"overtime_hours_per_week": "1.00", "subgoal_id": sub["id"]})
    assert r.status_code == 404


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"overtime_hours_per_week": "-1.00"},
        {"overtime_hours_per_week": "10.00", "standard_contribution": "-1.00"},
        {"overtime_hours_per_week": "1000.00"},
    ],
    ids=["missing_hours", "negative_hours", "negative_contribution", "hours_too_big"],
)
def test_projection_validation(api, rates, payload):
    assert api.post(PROJECTIONS, payload).status_code == 422


def test_negative_hours_cannot_cause_division_by_zero(api, make, rates):
    # Regression: -1h/wk makes monthly overtime -260.00, so a 260.00 standard
    # contribution used to divide by zero (500). It must be a validation error.
    goal = make.goal(target_amount="1000.00")
    r = api.post(
        PROJECTIONS,
        {
            "overtime_hours_per_week": "-1.00",
            "goal_id": goal["id"],
            "standard_contribution": "260.00",
        },
    )
    assert r.status_code == 422
