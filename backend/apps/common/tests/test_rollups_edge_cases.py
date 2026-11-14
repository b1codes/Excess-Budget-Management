"""Rollup helpers must be safe no-ops when what they'd update is already gone
(a concurrent delete, or a dangling reference), rather than raising or
resurrecting a document."""

from apps.common.firestore import get_client
from apps.common.rollups import (
    apply_allocation_effects,
    apply_expense_effects,
    recompute_goal_from_accounts,
    recompute_subgoal_parent,
)


def _doc(collection, doc_id):
    return get_client().collection(collection).document(doc_id).get()


def _set(collection, doc_id, data):
    get_client().collection(collection).document(doc_id).set(data)


def test_expense_effects_skip_missing_account_and_category():
    apply_expense_effects(
        old=None, new={"account_id": "gone", "budget_category_id": "gone", "amount_cents": 500}
    )
    assert not _doc("accounts", "gone").exists
    assert not _doc("budget_categories", "gone").exists


def test_zero_amount_effects_touch_nothing():
    _set("accounts", "acc", {"balance": 100})
    apply_expense_effects(
        old=None, new={"account_id": "acc", "budget_category_id": None, "amount_cents": 0}
    )
    assert _doc("accounts", "acc").get("balance") == 100


def test_recompute_subgoal_parent_skips_missing_goal():
    _set("sub_goals", "s1", {"goal_id": "gone", "target_amount": 1, "current_amount": 1})
    recompute_subgoal_parent("gone")
    assert not _doc("goals", "gone").exists


def test_recompute_goal_from_accounts_skips_missing_goal():
    recompute_goal_from_accounts("gone")
    assert not _doc("goals", "gone").exists


def test_recompute_goal_from_accounts_ignores_dangling_links():
    _set("goals", "g", {"current_amount": 999})
    _set("accounts", "a", {"balance": 40})
    _set("goal_accounts", "g_a", {"goal_id": "g", "account_id": "a"})
    _set("goal_accounts", "g_gone", {"goal_id": "g", "account_id": "gone"})
    recompute_goal_from_accounts("g")
    assert _doc("goals", "g").get("current_amount") == 40


def test_allocation_effects_skip_missing_subgoal_and_goal():
    _set("accounts", "acc", {"balance": 100})
    apply_allocation_effects(
        old=None,
        new={"account_id": "acc", "goal_id": "gone", "sub_goal_id": "gone", "amount_cents": 10},
    )
    apply_allocation_effects(
        old=None,
        new={"account_id": None, "goal_id": "gone", "sub_goal_id": None, "amount_cents": 10},
    )
    assert not _doc("sub_goals", "gone").exists
    assert not _doc("goals", "gone").exists
    # The account side still applies; only the missing targets are skipped.
    assert _doc("accounts", "acc").get("balance") == 90
