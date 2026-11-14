import pytest

pytestmark = pytest.mark.django_db


def test_create_defaults_balance_to_zero(api):
    r = api.post("/accounts", {"name": "Savings"})
    assert r.status_code == 201
    body = r.json()
    assert body["balance"] == "0.00"
    assert set(body) == {"id", "name", "balance", "created_at"}


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"name": ""},
        {"name": "x" * 201},
        {"name": "A", "balance": "-0.01"},
        {"name": "A", "balance": "1.234"},
        {"name": "A", "balance": "10000000000.00"},
        {"name": "A", "balance": "abc"},
    ],
    ids=["missing_name", "empty_name", "name_too_long", "negative", "3dp", "too_big", "nan"],
)
def test_create_validation(api, payload):
    assert api.post("/accounts", payload).status_code == 422


def test_get_returns_account(api, make):
    account = make.account(name="Checking", balance="12.34")
    assert make.get(f"/accounts/{account['id']}") == account


def test_list_is_ordered_by_creation(api, make):
    names = ["First", "Second", "Third"]
    for name in names:
        make.account(name=name)
    assert [a["name"] for a in make.get("/accounts")] == names


def test_list_empty(api):
    assert api.get("/accounts").json() == []


def test_patch_name_only_keeps_balance(api, make):
    account = make.account(name="Old", balance="50.00")
    r = api.patch(f"/accounts/{account['id']}", {"name": "New"})
    assert r.status_code == 200
    assert r.json()["name"] == "New"
    assert r.json()["balance"] == "50.00"


def test_patch_balance_only_keeps_name(api, make):
    account = make.account(name="Keep", balance="50.00")
    r = api.patch(f"/accounts/{account['id']}", {"balance": "75.25"})
    assert r.json() == {**account, "balance": "75.25"}


def test_empty_patch_is_a_no_op(api, make):
    account = make.account()
    r = api.patch(f"/accounts/{account['id']}", {})
    assert r.status_code == 200
    assert r.json() == account


@pytest.mark.parametrize(
    "payload", [{"name": ""}, {"balance": "-1.00"}, {"balance": "1.001"}], ids=str
)
def test_patch_validation(api, make, payload):
    account = make.account()
    assert api.patch(f"/accounts/{account['id']}", payload).status_code == 422
    assert make.get(f"/accounts/{account['id']}") == account


def test_patch_ignores_read_only_fields(api, make):
    account = make.account()
    r = api.patch(
        f"/accounts/{account['id']}", {"id": "00000000-0000-0000-0000-000000000000", "name": "N"}
    )
    assert r.json()["id"] == account["id"]


def test_delete(api, make):
    account = make.account()
    assert api.delete(f"/accounts/{account['id']}").status_code == 204
    assert api.get(f"/accounts/{account['id']}").status_code == 404
    assert make.get("/accounts") == []


def test_delete_twice_is_404(api, make):
    account = make.account()
    api.delete(f"/accounts/{account['id']}")
    assert api.delete(f"/accounts/{account['id']}").status_code == 404


def test_delete_unlinks_extra_income_and_allocations_but_keeps_them(api, make):
    account = make.account(balance="100.00")
    goal = make.goal()
    extra = make.extra_income(amount="10.00", account_id=account["id"])
    allocation = make.allocation(goal["id"], amount="5.00", account_id=account["id"])

    api.delete(f"/accounts/{account['id']}")

    assert make.get(f"/income/extra/{extra['id']}")["account_id"] is None
    assert make.get(f"/allocations/{allocation['id']}")["account_id"] is None
    # The goal keeps the progress the allocation already made.
    assert make.get(f"/goals/{goal['id']}")["current_amount"] == "5.00"


def test_delete_recomputes_every_linked_goal(api, make):
    account = make.account(balance="40.00")
    keep = make.account(balance="10.00")
    goals = [make.goal(name="A"), make.goal(name="B")]
    for goal in goals:
        api.post(f"/goals/{goal['id']}/accounts", {"account_id": account["id"]})
        api.post(f"/goals/{goal['id']}/accounts", {"account_id": keep["id"]})
        assert make.get(f"/goals/{goal['id']}")["current_amount"] == "50.00"

    api.delete(f"/accounts/{account['id']}")

    for goal in goals:
        assert make.get(f"/goals/{goal['id']}")["current_amount"] == "10.00"
