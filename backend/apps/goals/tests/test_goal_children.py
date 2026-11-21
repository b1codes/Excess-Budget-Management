"""GoalOut embeds the goal's subgoals and linked account ids.

The Flutter client reads both from the goal itself (goal detail, subgoal
edit/delete, unlinking accounts, the overtime subgoal picker), so every
endpoint that returns a goal must include them.
"""

import pytest

pytestmark = pytest.mark.django_db


def test_new_goal_has_empty_children(make):
    goal = make.goal()
    assert goal["sub_goals"] == []
    assert goal["account_ids"] == []


def test_get_goal_embeds_subgoals_oldest_first(api, make):
    goal = make.goal()
    first = make.subgoal(goal["id"], name="First")
    second = make.subgoal(goal["id"], name="Second", current_amount="5.00")

    body = make.get(f"/goals/{goal['id']}")

    assert [s["id"] for s in body["sub_goals"]] == [first["id"], second["id"]]
    # Same shape as GET /goals/{id}/subgoals, so the client can parse either.
    assert body["sub_goals"] == make.get(f"/goals/{goal['id']}/subgoals")


def test_get_goal_embeds_linked_account_ids_in_link_order(api, make):
    goal = make.goal()
    b = make.account(name="B")
    a = make.account(name="A")
    api.post(f"/goals/{goal['id']}/accounts", {"account_id": b["id"]})
    api.post(f"/goals/{goal['id']}/accounts", {"account_id": a["id"]})

    assert make.get(f"/goals/{goal['id']}")["account_ids"] == [b["id"], a["id"]]


def test_unlinked_account_disappears(api, make):
    goal = make.goal()
    account = make.account()
    api.post(f"/goals/{goal['id']}/accounts", {"account_id": account["id"]})
    api.delete(f"/goals/{goal['id']}/accounts/{account['id']}")

    assert make.get(f"/goals/{goal['id']}")["account_ids"] == []


def test_deleted_subgoal_disappears(api, make):
    goal = make.goal()
    sub = make.subgoal(goal["id"])
    api.delete(f"/goals/{goal['id']}/subgoals/{sub['id']}")

    assert make.get(f"/goals/{goal['id']}")["sub_goals"] == []


def test_list_groups_children_under_the_right_goal(api, make):
    g1 = make.goal(name="One")
    g2 = make.goal(name="Two")
    make.goal(name="Empty")
    s1 = make.subgoal(g1["id"], name="for one")
    s2 = make.subgoal(g2["id"], name="for two")
    account = make.account()
    api.post(f"/goals/{g2['id']}/accounts", {"account_id": account["id"]})

    goals = {g["name"]: g for g in make.get("/goals")}

    assert [s["id"] for s in goals["One"]["sub_goals"]] == [s1["id"]]
    assert goals["One"]["account_ids"] == []
    assert [s["id"] for s in goals["Two"]["sub_goals"]] == [s2["id"]]
    assert goals["Two"]["account_ids"] == [account["id"]]
    assert goals["Empty"]["sub_goals"] == []
    assert goals["Empty"]["account_ids"] == []


def test_patch_returns_children(api, make):
    goal = make.goal()
    sub = make.subgoal(goal["id"])

    r = api.patch(f"/goals/{goal['id']}", {"name": "Renamed"})

    assert r.status_code == 200
    assert [s["id"] for s in r.json()["sub_goals"]] == [sub["id"]]


def test_other_users_children_never_leak(api, other_api, make):
    mine = make.goal()
    make.subgoal(mine["id"])
    theirs = make.as_(other_api).goal()
    make.as_(other_api).subgoal(theirs["id"])

    assert len(make.get("/goals")[0]["sub_goals"]) == 1
    assert len(make.as_(other_api).get("/goals")[0]["sub_goals"]) == 1
