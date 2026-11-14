"""Income sources and extra income: CRUD, validation, and the account-balance
and budget rollups that extra income drives."""

import pytest

pytestmark = pytest.mark.django_db


def balance(make, account) -> str:
    return make.get(f"/accounts/{account['id']}")["balance"]


def spent(make, category) -> str:
    return make.get(f"/budget/categories/{category['id']}")["spent_amount"]


# --- Income sources ---------------------------------------------------------------


def test_source_get_list_and_order(api, make):
    first = make.income_source(name="Salary")
    second = make.income_source(name="Side gig", frequency="weekly")
    assert make.get(f"/income/sources/{first['id']}") == first
    assert make.get("/income/sources") == [first, second]


@pytest.mark.parametrize(
    "field,value", [("name", "Bonus"), ("expected_amount", "123.45"), ("frequency", "yearly")]
)
def test_source_patch_single_field(api, make, field, value):
    source = make.income_source()
    r = api.patch(f"/income/sources/{source['id']}", {field: value})
    assert r.status_code == 200
    assert r.json() == {**source, field: value}


def test_source_empty_patch_is_a_no_op(api, make):
    source = make.income_source()
    assert api.patch(f"/income/sources/{source['id']}", {}).json() == source


@pytest.mark.parametrize(
    "payload",
    [
        {"expected_amount": "1.00", "frequency": "monthly"},
        {"name": "", "expected_amount": "1.00", "frequency": "monthly"},
        {"name": "S", "frequency": "monthly"},
        {"name": "S", "expected_amount": "1.00"},
        {"name": "S", "expected_amount": "1.001", "frequency": "monthly"},
    ],
    ids=["no_name", "empty_name", "no_amount", "no_frequency", "3dp"],
)
def test_source_create_validation(api, payload):
    assert api.post("/income/sources", payload).status_code == 422


def test_source_delete(api, make):
    source = make.income_source()
    assert api.delete(f"/income/sources/{source['id']}").status_code == 204
    assert api.get(f"/income/sources/{source['id']}").status_code == 404
    assert make.get("/income/sources") == []


# --- Extra income -------------------------------------------------------------------


@pytest.fixture
def world(make):
    return {
        "checking": make.account(name="Checking", balance="100.00"),
        "savings": make.account(name="Savings", balance="100.00"),
        "bonus": make.category(name="Bonus", category_type="income"),
        "food": make.category(name="Food", category_type="expense"),
    }


def test_extra_without_links_has_no_side_effects(api, make, world):
    extra = make.extra_income(amount="10.00")
    assert extra["account_id"] is None and extra["budget_category_id"] is None
    assert balance(make, world["checking"]) == "100.00"


def test_extra_patch_amount_adjusts_by_difference(api, make, world):
    extra = make.extra_income(
        amount="20.00", account_id=world["checking"]["id"], budget_category_id=world["bonus"]["id"]
    )
    assert balance(make, world["checking"]) == "120.00"
    assert spent(make, world["bonus"]) == "20.00"

    api.patch(f"/income/extra/{extra['id']}", {"amount": "5.00"})

    assert balance(make, world["checking"]) == "105.00"
    assert spent(make, world["bonus"]) == "5.00"


def test_extra_patch_moves_between_accounts(api, make, world):
    extra = make.extra_income(amount="20.00", account_id=world["checking"]["id"])
    api.patch(f"/income/extra/{extra['id']}", {"account_id": world["savings"]["id"]})
    assert balance(make, world["checking"]) == "100.00"
    assert balance(make, world["savings"]) == "120.00"


def test_extra_patch_clears_account_and_category(api, make, world):
    extra = make.extra_income(
        amount="20.00", account_id=world["checking"]["id"], budget_category_id=world["bonus"]["id"]
    )

    r = api.patch(f"/income/extra/{extra['id']}", {"account_id": None, "budget_category_id": None})

    assert r.json()["account_id"] is None and r.json()["budget_category_id"] is None
    assert balance(make, world["checking"]) == "100.00"
    assert spent(make, world["bonus"]) == "0.00"


def test_extra_patch_into_expense_category_flips_the_sign(api, make, world):
    extra = make.extra_income(amount="20.00", budget_category_id=world["bonus"]["id"])
    api.patch(f"/income/extra/{extra['id']}", {"budget_category_id": world["food"]["id"]})
    assert spent(make, world["bonus"]) == "0.00"
    # Income booked against an expense category reduces what was spent.
    assert spent(make, world["food"]) == "-20.00"


def test_extra_patch_metadata_only(api, make, world):
    extra = make.extra_income(amount="20.00", account_id=world["checking"]["id"])
    r = api.patch(
        f"/income/extra/{extra['id']}", {"description": "Refund", "date_received": "2026-05-05"}
    )
    assert r.json()["description"] == "Refund" and r.json()["date_received"] == "2026-05-05"
    assert balance(make, world["checking"]) == "120.00"


def test_extra_delete_reverses_effects(api, make, world):
    extra = make.extra_income(
        amount="20.00", account_id=world["checking"]["id"], budget_category_id=world["bonus"]["id"]
    )
    assert api.delete(f"/income/extra/{extra['id']}").status_code == 204
    assert balance(make, world["checking"]) == "100.00"
    assert spent(make, world["bonus"]) == "0.00"
    assert api.get(f"/income/extra/{extra['id']}").status_code == 404


@pytest.mark.parametrize("field", ["account_id", "budget_category_id"])
def test_extra_rejects_another_users_reference(api, other_api, make, world, field):
    theirs = make.as_(other_api)
    foreign = {"account_id": theirs.account(), "budget_category_id": theirs.category()}[field]["id"]

    assert (
        api.post(
            "/income/extra", {"amount": "1.00", "date_received": "2026-01-01", field: foreign}
        ).status_code
        == 404
    )
    extra = make.extra_income(amount="1.00")
    assert api.patch(f"/income/extra/{extra['id']}", {field: foreign}).status_code == 404
    assert make.get("/income/extra") == [extra]


def test_extra_list_order_and_filters(api, make, world):
    checking, bonus = world["checking"]["id"], world["bonus"]["id"]
    old = make.extra_income(date_received="2026-01-01", account_id=checking)
    new = make.extra_income(
        date_received="2026-02-01", account_id=checking, budget_category_id=bonus
    )
    unlinked = make.extra_income(date_received="2026-03-01")

    assert [e["id"] for e in make.get("/income/extra")] == [unlinked["id"], new["id"], old["id"]]
    by_account = api.get("/income/extra", {"account_id": checking}).json()
    assert [e["id"] for e in by_account] == [new["id"], old["id"]]
    both = api.get("/income/extra", {"account_id": checking, "budget_category_id": bonus}).json()
    assert [e["id"] for e in both] == [new["id"]]


@pytest.mark.parametrize(
    "payload",
    [{"date_received": "2026-01-01"}, {"amount": "1.00"}, {"amount": "x", "date_received": "x"}],
    ids=["no_amount", "no_date", "garbage"],
)
def test_extra_create_validation(api, payload):
    assert api.post("/income/extra", payload).status_code == 422
