"""Allocation GET/PATCH and the account-balance / goal / subgoal progress
rollups that PATCH must keep consistent."""

import pytest

pytestmark = pytest.mark.django_db


@pytest.fixture
def world(make):
    trip, house = make.goal(name="Trip"), make.goal(name="House")
    return {
        "checking": make.account(name="Checking", balance="500.00"),
        "savings": make.account(name="Savings", balance="500.00"),
        "trip": trip,
        "house": house,
        "flights": make.subgoal(trip["id"], name="Flights", target_amount="300.00"),
        "hotel": make.subgoal(trip["id"], name="Hotel", target_amount="200.00"),
        "deposit": make.subgoal(house["id"], name="Deposit", target_amount="900.00"),
    }


def current(make, goal) -> str:
    return make.get(f"/goals/{goal['id']}")["current_amount"]


def sub_current(make, goal, sub) -> str:
    subs = make.get(f"/goals/{goal['id']}/subgoals")
    return next(s for s in subs if s["id"] == sub["id"])["current_amount"]


def balance(make, account) -> str:
    return make.get(f"/accounts/{account['id']}")["balance"]


def test_get_allocation(api, make, world):
    allocation = make.allocation(world["trip"]["id"], sub_goal_id=world["flights"]["id"])
    assert make.get(f"/allocations/{allocation['id']}") == allocation


def test_patch_amount(api, make, world):
    allocation = make.allocation(
        world["trip"]["id"],
        amount="50.00",
        sub_goal_id=world["flights"]["id"],
        account_id=world["checking"]["id"],
    )

    r = api.patch(f"/allocations/{allocation['id']}", {"amount": "80.00"})

    assert r.status_code == 200 and r.json()["amount"] == "80.00"
    assert balance(make, world["checking"]) == "420.00"
    assert sub_current(make, world["trip"], world["flights"]) == "80.00"
    assert current(make, world["trip"]) == "80.00"


def test_patch_moves_between_subgoals_of_the_same_goal(api, make, world):
    allocation = make.allocation(
        world["trip"]["id"], amount="50.00", sub_goal_id=world["flights"]["id"]
    )

    api.patch(f"/allocations/{allocation['id']}", {"sub_goal_id": world["hotel"]["id"]})

    assert sub_current(make, world["trip"], world["flights"]) == "0.00"
    assert sub_current(make, world["trip"], world["hotel"]) == "50.00"
    assert current(make, world["trip"]) == "50.00"


def test_patch_moves_to_another_goal_and_its_subgoal(api, make, world):
    allocation = make.allocation(
        world["trip"]["id"], amount="50.00", sub_goal_id=world["flights"]["id"]
    )

    r = api.patch(
        f"/allocations/{allocation['id']}",
        {"goal_id": world["house"]["id"], "sub_goal_id": world["deposit"]["id"]},
    )

    assert r.status_code == 200
    assert current(make, world["trip"]) == "0.00"
    assert sub_current(make, world["house"], world["deposit"]) == "50.00"
    assert current(make, world["house"]) == "50.00"


def test_patch_goal_without_moving_the_subgoal_is_rejected(api, make, world):
    # Regression: changing goal_id alone kept the old goal's subgoal, leaving an
    # allocation whose subgoal belongs to a different goal than its goal_id.
    allocation = make.allocation(
        world["trip"]["id"], amount="50.00", sub_goal_id=world["flights"]["id"]
    )

    r = api.patch(f"/allocations/{allocation['id']}", {"goal_id": world["house"]["id"]})

    assert r.status_code == 400
    assert r.json()["error"]["code"] == "subgoal_goal_mismatch"
    assert make.get(f"/allocations/{allocation['id']}") == allocation
    assert current(make, world["trip"]) == "50.00"
    assert current(make, world["house"]) == "0.00"


def test_patch_goal_and_clear_subgoal(api, make, world):
    goal_only = make.goal(name="Car")
    allocation = make.allocation(
        world["trip"]["id"], amount="50.00", sub_goal_id=world["flights"]["id"]
    )

    r = api.patch(
        f"/allocations/{allocation['id']}", {"goal_id": goal_only["id"], "sub_goal_id": None}
    )

    assert r.status_code == 200 and r.json()["sub_goal_id"] is None
    assert current(make, world["trip"]) == "0.00"
    assert current(make, goal_only) == "50.00"


def test_patch_subgoal_that_belongs_to_another_goal_is_rejected(api, make, world):
    allocation = make.allocation(
        world["trip"]["id"], amount="50.00", sub_goal_id=world["flights"]["id"]
    )

    r = api.patch(f"/allocations/{allocation['id']}", {"sub_goal_id": world["deposit"]["id"]})

    assert r.status_code == 400
    assert r.json()["error"]["code"] == "subgoal_goal_mismatch"
    assert make.get(f"/allocations/{allocation['id']}") == allocation


def test_patch_moves_between_accounts_and_clears(api, make, world):
    allocation = make.allocation(
        world["trip"]["id"], amount="50.00", account_id=world["checking"]["id"]
    )

    api.patch(f"/allocations/{allocation['id']}", {"account_id": world["savings"]["id"]})
    assert balance(make, world["checking"]) == "500.00"
    assert balance(make, world["savings"]) == "450.00"

    r = api.patch(f"/allocations/{allocation['id']}", {"account_id": None})
    assert r.json()["account_id"] is None
    assert balance(make, world["savings"]) == "500.00"


@pytest.mark.parametrize("field", ["goal_id", "sub_goal_id", "account_id"])
def test_create_and_patch_reject_another_users_reference(api, other_api, make, world, field):
    theirs = make.as_(other_api)
    their_goal = theirs.goal()
    foreign = {
        "goal_id": their_goal["id"],
        "sub_goal_id": theirs.subgoal(their_goal["id"])["id"],
        "account_id": theirs.account()["id"],
    }[field]
    payload = {"goal_id": world["trip"]["id"], "amount": "10.00", field: foreign}

    assert api.post("/allocations", payload).status_code == 404

    allocation = make.allocation(world["trip"]["id"], amount="10.00")
    assert api.patch(f"/allocations/{allocation['id']}", {field: foreign}).status_code == 404
    assert make.get("/allocations") == [allocation]


def test_list_is_newest_first(api, make, world):
    ids = [make.allocation(world["trip"]["id"])["id"] for _ in range(3)]
    assert [a["id"] for a in make.get("/allocations")] == ids[::-1]


@pytest.mark.parametrize(
    "override",
    [
        {"goal_id": None},
        {"goal_id": "nope"},
        {"amount": None},
        {"amount": "1.001"},
        {"sub_goal_id": "nope"},
    ],
    ids=["no_goal", "bad_goal_id", "no_amount", "3dp", "bad_sub_goal_id"],
)
def test_create_validation(api, make, world, override):
    payload = {"goal_id": world["trip"]["id"], "amount": "1.00", **override}
    payload = {k: v for k, v in payload.items() if v is not None}
    assert api.post("/allocations", payload).status_code == 422
    assert make.get("/allocations") == []


# --- Summary --------------------------------------------------------------------


def test_summary_is_zero_without_allocations(api):
    assert api.get("/allocations/summary").json() == {"totalSavings": 0.0, "totalPurchases": 0.0}


def test_summary_buckets_by_goal_category_and_skips_deleted_goals(api, make):
    savings = make.goal(name="Rainy day", category="savings")
    purchase = make.goal(name="Laptop", category="purchase")
    doomed = make.goal(name="Gone", category="savings")
    make.allocation(savings["id"], amount="10.00")
    make.allocation(purchase["id"], amount="2.50")
    make.allocation(doomed["id"], amount="99.00")
    api.delete(f"/goals/{doomed['id']}")

    assert make.get("/allocations/summary") == {"totalSavings": 10.0, "totalPurchases": 2.5}


def test_summary_respects_days_window(api, make):
    from datetime import datetime, timedelta, timezone

    from apps.common.firestore import get_client

    goal = make.goal(category="savings")
    recent = make.allocation(goal["id"], amount="10.00")
    old = make.allocation(goal["id"], amount="5.00")
    get_client().collection("allocations").document(old["id"]).update(
        {"created_at": datetime.now(timezone.utc) - timedelta(days=10)}
    )
    assert recent

    assert api.get("/allocations/summary", {"days": 30}).json()["totalSavings"] == 15.0
    assert api.get("/allocations/summary", {"days": 7}).json()["totalSavings"] == 10.0


def test_summary_only_counts_own_allocations(api, other_api, make):
    theirs = make.as_(other_api)
    theirs.allocation(theirs.goal(category="savings")["id"], amount="10.00")
    assert make.get("/allocations/summary")["totalSavings"] == 0.0
