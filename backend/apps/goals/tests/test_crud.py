"""Goals, subgoals, and goal-account links: CRUD, validation, and the
target/current rollups between them."""

import pytest

pytestmark = pytest.mark.django_db


def goal_of(make, goal) -> dict:
    return make.get(f"/goals/{goal['id']}")


# --- Goals ------------------------------------------------------------------------


def test_create_defaults(api):
    body = api.post("/goals", {"name": "Fund", "type": "long_term"}).json()
    assert body["target_amount"] == "0.00"
    assert body["current_amount"] == "0.00"
    assert body["category"] == "savings"
    assert body["target_date"] is None


def test_create_ignores_current_amount(api):
    body = api.post(
        "/goals", {"name": "Fund", "type": "long_term", "current_amount": "500.00"}
    ).json()
    assert body["current_amount"] == "0.00"


@pytest.mark.parametrize(
    "payload",
    [
        {"type": "short_term"},
        {"name": "", "type": "short_term"},
        {"name": "G"},
        {"name": "G", "type": "forever"},
        {"name": "G", "type": "short_term", "category": "investment"},
        {"name": "G", "type": "short_term", "target_date": "soon"},
        {"name": "G", "type": "short_term", "target_amount": "1.001"},
    ],
    ids=["no_name", "empty_name", "no_type", "bad_type", "bad_category", "bad_date", "3dp"],
)
def test_create_validation(api, payload):
    assert api.post("/goals", payload).status_code == 422


def test_get_and_list_order(api, make):
    goals = [make.goal(name=n) for n in ("A", "B", "C")]
    assert make.get(f"/goals/{goals[1]['id']}") == goals[1]
    assert make.get("/goals") == goals


@pytest.mark.parametrize(
    "field,value",
    [
        ("name", "Renamed"),
        ("target_amount", "2500.00"),
        ("target_date", "2027-06-30"),
        ("type", "long_term"),
        ("category", "purchase"),
    ],
)
def test_patch_single_field(api, make, field, value):
    goal = make.goal()
    r = api.patch(f"/goals/{goal['id']}", {field: value})
    assert r.status_code == 200
    assert r.json() == {**goal, field: value}


def test_empty_patch_is_a_no_op(api, make):
    goal = make.goal(target_date="2027-01-01")
    assert api.patch(f"/goals/{goal['id']}", {}).json() == goal


def test_patch_null_target_date_keeps_it(api, make):
    # Documents current behaviour: PATCH can set a target_date but not clear it.
    goal = make.goal(target_date="2027-01-01")
    assert api.patch(f"/goals/{goal['id']}", {"target_date": None}).json()["target_date"] == (
        "2027-01-01"
    )


@pytest.mark.parametrize(
    "payload", [{"type": "forever"}, {"category": "x"}, {"target_amount": "x"}], ids=str
)
def test_patch_validation(api, make, payload):
    goal = make.goal()
    assert api.patch(f"/goals/{goal['id']}", payload).status_code == 422
    assert goal_of(make, goal) == goal


def test_delete_cascades_subgoals_links_and_allocations(api, make):
    account = make.account(balance="100.00")
    goal = make.goal()
    sub = make.subgoal(goal["id"])
    api.post(f"/goals/{goal['id']}/accounts", {"account_id": account["id"]})
    allocation = make.allocation(goal["id"], amount="10.00", sub_goal_id=sub["id"])
    keep = make.goal(name="Keep")
    kept_allocation = make.allocation(keep["id"], amount="1.00")

    assert api.delete(f"/goals/{goal['id']}").status_code == 204

    assert api.get(f"/goals/{goal['id']}").status_code == 404
    assert api.get(f"/goals/{goal['id']}/subgoals").status_code == 404
    assert api.get(f"/allocations/{allocation['id']}").status_code == 404
    assert make.get("/allocations") == [kept_allocation]
    assert make.get("/goals") == [goal_of(make, keep)]
    # The account itself survives; only the link is gone.
    assert make.get(f"/accounts/{account['id']}")["balance"] == "100.00"


# --- Subgoals -----------------------------------------------------------------------


def test_subgoals_drive_parent_totals(api, make):
    goal = make.goal(target_amount="9999.00")
    make.subgoal(goal["id"], target_amount="300.00", current_amount="50.00")
    make.subgoal(goal["id"], target_amount="200.00", current_amount="25.00")
    body = goal_of(make, goal)
    assert body["target_amount"] == "500.00"
    assert body["current_amount"] == "75.00"


def test_subgoal_list_order(api, make):
    goal = make.goal()
    subs = [make.subgoal(goal["id"], name=n) for n in ("A", "B", "C")]
    assert make.get(f"/goals/{goal['id']}/subgoals") == subs


@pytest.mark.parametrize(
    "field,value",
    [("name", "Renamed"), ("target_amount", "123.00"), ("current_amount", "7.00")],
)
def test_subgoal_patch_single_field(api, make, field, value):
    goal = make.goal()
    sub = make.subgoal(goal["id"], target_amount="100.00", current_amount="1.00")
    r = api.patch(f"/goals/{goal['id']}/subgoals/{sub['id']}", {field: value})
    assert r.status_code == 200
    assert r.json() == {**sub, field: value}


def test_subgoal_patch_recomputes_parent(api, make):
    goal = make.goal()
    a = make.subgoal(goal["id"], target_amount="100.00", current_amount="10.00")
    make.subgoal(goal["id"], target_amount="100.00", current_amount="10.00")

    api.patch(f"/goals/{goal['id']}/subgoals/{a['id']}", {"target_amount": "400.00"})
    api.patch(f"/goals/{goal['id']}/subgoals/{a['id']}", {"current_amount": "90.00"})

    body = goal_of(make, goal)
    assert body["target_amount"] == "500.00"
    assert body["current_amount"] == "100.00"


def test_deleting_one_subgoal_recomputes_parent(api, make):
    goal = make.goal()
    a = make.subgoal(goal["id"], target_amount="100.00", current_amount="10.00")
    make.subgoal(goal["id"], target_amount="50.00", current_amount="5.00")

    assert api.delete(f"/goals/{goal['id']}/subgoals/{a['id']}").status_code == 204

    body = goal_of(make, goal)
    assert (body["target_amount"], body["current_amount"]) == ("50.00", "5.00")


def test_deleting_the_last_subgoal_leaves_parent_totals(api, make):
    # Documents current behaviour: with no subgoals left there is nothing to
    # sum, so the parent keeps the totals from its last subgoal.
    goal = make.goal(target_amount="1000.00")
    sub = make.subgoal(goal["id"], target_amount="300.00", current_amount="30.00")

    api.delete(f"/goals/{goal['id']}/subgoals/{sub['id']}")

    body = goal_of(make, goal)
    assert (body["target_amount"], body["current_amount"]) == ("300.00", "30.00")


@pytest.mark.parametrize(
    "payload",
    [
        {"target_amount": "1.00"},
        {"name": "", "target_amount": "1.00"},
        {"name": "S"},
        {"name": "S", "target_amount": "1.001"},
    ],
    ids=["no_name", "empty_name", "no_target", "3dp"],
)
def test_subgoal_create_validation(api, make, payload):
    goal = make.goal()
    assert api.post(f"/goals/{goal['id']}/subgoals", payload).status_code == 422
    assert make.get(f"/goals/{goal['id']}/subgoals") == []


@pytest.mark.parametrize("method", ["PATCH", "DELETE"])
def test_subgoal_addressed_through_the_wrong_goal_is_404(api, make, method):
    owner, other = make.goal(name="Owner"), make.goal(name="Other")
    sub = make.subgoal(owner["id"])
    path = f"/goals/{other['id']}/subgoals/{sub['id']}"
    r = api.patch(path, {"name": "x"}) if method == "PATCH" else api.delete(path)
    assert r.status_code == 404
    assert make.get(f"/goals/{owner['id']}/subgoals") == [sub]


# --- Goal-account links -----------------------------------------------------------


def test_link_returns_the_link(api, make):
    goal, account = make.goal(), make.account()
    r = api.post(f"/goals/{goal['id']}/accounts", {"account_id": account["id"]})
    assert r.status_code == 201
    body = r.json()
    assert (body["goal_id"], body["account_id"]) == (goal["id"], account["id"])
    assert "created_at" in body


def test_linking_twice_counts_the_account_once(api, make):
    goal, account = make.goal(), make.account(balance="40.00")
    for _ in range(2):
        api.post(f"/goals/{goal['id']}/accounts", {"account_id": account["id"]})
    assert goal_of(make, goal)["current_amount"] == "40.00"


def test_unlink_recomputes_and_is_idempotent(api, make):
    goal = make.goal()
    a, b = make.account(balance="40.00"), make.account(balance="2.00")
    for account in (a, b):
        api.post(f"/goals/{goal['id']}/accounts", {"account_id": account["id"]})
    assert goal_of(make, goal)["current_amount"] == "42.00"

    assert api.delete(f"/goals/{goal['id']}/accounts/{a['id']}").status_code == 204
    assert goal_of(make, goal)["current_amount"] == "2.00"
    assert api.delete(f"/goals/{goal['id']}/accounts/{a['id']}").status_code == 204
    assert goal_of(make, goal)["current_amount"] == "2.00"


def test_unlinking_the_last_account_zeroes_current(api, make):
    goal, account = make.goal(), make.account(balance="40.00")
    api.post(f"/goals/{goal['id']}/accounts", {"account_id": account["id"]})
    api.delete(f"/goals/{goal['id']}/accounts/{account['id']}")
    assert goal_of(make, goal)["current_amount"] == "0.00"


def test_cannot_link_another_users_account(api, other_api, make):
    goal = make.goal()
    their_account = make.as_(other_api).account(balance="1000.00")
    r = api.post(f"/goals/{goal['id']}/accounts", {"account_id": their_account["id"]})
    assert r.status_code == 404
    assert goal_of(make, goal)["current_amount"] == "0.00"


def test_link_validation(api, make):
    goal = make.goal()
    assert api.post(f"/goals/{goal['id']}/accounts", {}).status_code == 422
    assert api.post(f"/goals/{goal['id']}/accounts", {"account_id": "x"}).status_code == 422
