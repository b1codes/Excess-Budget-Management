"""Expense GET/PATCH/list behaviour, and the account-balance and budget
spent_amount rollups that PATCH must keep consistent."""

import pytest

pytestmark = pytest.mark.django_db


@pytest.fixture
def world(make):
    return {
        "checking": make.account(name="Checking", balance="100.00"),
        "savings": make.account(name="Savings", balance="100.00"),
        "food": make.category(name="Food", category_type="expense"),
        "fun": make.category(name="Fun", category_type="expense"),
        "salary": make.category(name="Salary", category_type="income"),
    }


def balance(make, account) -> str:
    return make.get(f"/accounts/{account['id']}")["balance"]


def spent(make, category) -> str:
    return make.get(f"/budget/categories/{category['id']}")["spent_amount"]


def test_get_expense(api, make, world):
    expense = make.expense(world["food"]["id"], amount="12.50", description="Lunch")
    assert make.get(f"/expenses/{expense['id']}") == expense


def test_patch_amount_adjusts_balance_and_spent_by_the_difference(api, make, world):
    expense = make.expense(world["food"]["id"], amount="30.00", account_id=world["checking"]["id"])

    r = api.patch(f"/expenses/{expense['id']}", {"amount": "45.00"})

    assert r.status_code == 200 and r.json()["amount"] == "45.00"
    assert balance(make, world["checking"]) == "55.00"
    assert spent(make, world["food"]) == "45.00"


def test_patch_moves_between_accounts(api, make, world):
    expense = make.expense(world["food"]["id"], amount="20.00", account_id=world["checking"]["id"])

    api.patch(f"/expenses/{expense['id']}", {"account_id": world["savings"]["id"]})

    assert balance(make, world["checking"]) == "100.00"
    assert balance(make, world["savings"]) == "80.00"


def test_patch_clearing_account_restores_its_balance(api, make, world):
    expense = make.expense(world["food"]["id"], amount="20.00", account_id=world["checking"]["id"])

    r = api.patch(f"/expenses/{expense['id']}", {"account_id": None})

    assert r.json()["account_id"] is None
    assert balance(make, world["checking"]) == "100.00"
    assert spent(make, world["food"]) == "20.00"


def test_patch_omitting_account_keeps_it(api, make, world):
    expense = make.expense(world["food"]["id"], amount="20.00", account_id=world["checking"]["id"])
    r = api.patch(f"/expenses/{expense['id']}", {"description": "edited"})
    assert r.json()["account_id"] == world["checking"]["id"]
    assert balance(make, world["checking"]) == "80.00"


def test_patch_moves_between_categories(api, make, world):
    expense = make.expense(world["food"]["id"], amount="15.00")

    api.patch(f"/expenses/{expense['id']}", {"budget_category_id": world["fun"]["id"]})

    assert spent(make, world["food"]) == "0.00"
    assert spent(make, world["fun"]) == "15.00"


def test_patch_into_income_category_flips_the_sign(api, make, world):
    expense = make.expense(world["food"]["id"], amount="15.00")

    api.patch(f"/expenses/{expense['id']}", {"budget_category_id": world["salary"]["id"]})

    assert spent(make, world["food"]) == "0.00"
    assert spent(make, world["salary"]) == "-15.00"


def test_patch_amount_account_and_category_together(api, make, world):
    expense = make.expense(world["food"]["id"], amount="10.00", account_id=world["checking"]["id"])

    api.patch(
        f"/expenses/{expense['id']}",
        {
            "amount": "25.00",
            "account_id": world["savings"]["id"],
            "budget_category_id": world["fun"]["id"],
        },
    )

    assert balance(make, world["checking"]) == "100.00"
    assert balance(make, world["savings"]) == "75.00"
    assert spent(make, world["food"]) == "0.00"
    assert spent(make, world["fun"]) == "25.00"


def test_patch_description_and_date_leave_rollups_alone(api, make, world):
    expense = make.expense(world["food"]["id"], amount="10.00", account_id=world["checking"]["id"])

    r = api.patch(f"/expenses/{expense['id']}", {"description": "Dinner", "date": "2026-02-01"})

    assert r.json()["description"] == "Dinner" and r.json()["date"] == "2026-02-01"
    assert balance(make, world["checking"]) == "90.00"
    assert spent(make, world["food"]) == "10.00"


def test_repeated_patches_do_not_drift(api, make, world):
    expense = make.expense(world["food"]["id"], amount="10.00", account_id=world["checking"]["id"])
    for _ in range(3):
        api.patch(f"/expenses/{expense['id']}", {"amount": "10.00"})
    assert balance(make, world["checking"]) == "90.00"
    assert spent(make, world["food"]) == "10.00"


@pytest.mark.parametrize("field", ["account_id", "budget_category_id"])
def test_patch_rejects_another_users_reference_without_side_effects(
    api, other_api, make, world, field
):
    theirs = make.as_(other_api)
    foreign = {
        "account_id": theirs.account()["id"],
        "budget_category_id": theirs.category()["id"],
    }[field]
    expense = make.expense(world["food"]["id"], amount="10.00", account_id=world["checking"]["id"])

    r = api.patch(f"/expenses/{expense['id']}", {field: foreign, "amount": "99.00"})

    assert r.status_code == 404
    assert make.get(f"/expenses/{expense['id']}") == expense
    assert balance(make, world["checking"]) == "90.00"


@pytest.mark.parametrize("field", ["account_id", "budget_category_id"])
def test_create_rejects_another_users_reference_without_side_effects(
    api, other_api, make, world, field
):
    theirs = make.as_(other_api)
    payload = {
        "budget_category_id": world["food"]["id"],
        "account_id": world["checking"]["id"],
        "amount": "10.00",
        "date": "2026-01-01",
    }
    payload[field] = {
        "account_id": theirs.account()["id"],
        "budget_category_id": theirs.category()["id"],
    }[field]

    assert api.post("/expenses", payload).status_code == 404
    assert make.get("/expenses") == []
    assert balance(make, world["checking"]) == "100.00"


@pytest.mark.parametrize(
    "override",
    [
        {"budget_category_id": "nope"},
        {"account_id": "nope"},
        {"amount": "1.001"},
        {"amount": None},
        {"date": "2026-13-01"},
        {"date": None},
    ],
    ids=["bad_category_id", "bad_account_id", "3dp", "no_amount", "bad_date", "no_date"],
)
def test_create_validation(api, make, world, override):
    payload = {"budget_category_id": world["food"]["id"], "amount": "1.00", "date": "2026-01-01"}
    payload.update(override)
    payload = {k: v for k, v in payload.items() if v is not None}
    assert api.post("/expenses", payload).status_code == 422
    assert make.get("/expenses") == []


def test_create_requires_a_category(api):
    r = api.post("/expenses", {"amount": "1.00", "date": "2026-01-01"})
    assert r.status_code == 422


def test_list_is_newest_date_first_then_newest_created(api, make, world):
    food = world["food"]["id"]
    older = make.expense(food, date="2026-01-01", description="older")
    first_same_day = make.expense(food, date="2026-03-01", description="same-day 1")
    second_same_day = make.expense(food, date="2026-03-01", description="same-day 2")
    newest = make.expense(food, date="2026-04-01", description="newest")

    ids = [e["id"] for e in make.get("/expenses")]

    assert ids == [newest["id"], second_same_day["id"], first_same_day["id"], older["id"]]


def test_list_filters_combine(api, make, world):
    food, fun = world["food"]["id"], world["fun"]["id"]
    checking, savings = world["checking"]["id"], world["savings"]["id"]
    match = make.expense(food, account_id=checking)
    make.expense(food, account_id=savings)
    make.expense(fun, account_id=checking)

    r = api.get("/expenses", {"account_id": checking, "budget_category_id": food})

    assert [e["id"] for e in r.json()] == [match["id"]]
