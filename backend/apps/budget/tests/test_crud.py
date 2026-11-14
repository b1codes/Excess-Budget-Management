import pytest

pytestmark = pytest.mark.django_db


def test_create_returns_all_fields(api):
    r = api.post(
        "/budget/categories",
        {
            "name": "Dining",
            "limit_amount": "250.00",
            "category_type": "expense",
            "icon_code": 57534,
            "color_hex": "#FF5722",
        },
    )
    assert r.status_code == 201
    body = r.json()
    assert body["spent_amount"] == "0.00"
    assert body["icon_code"] == 57534
    assert body["color_hex"] == "#FF5722"


def test_create_defaults(api):
    body = api.post("/budget/categories", {"name": "Misc", "limit_amount": "10.00"}).json()
    assert body["category_type"] == "expense"
    assert body["icon_code"] is None
    assert body["color_hex"] is None


@pytest.mark.parametrize(
    "payload",
    [
        {"limit_amount": "1.00"},
        {"name": "", "limit_amount": "1.00"},
        {"name": "x" * 201, "limit_amount": "1.00"},
        {"name": "A"},
        {"name": "A", "limit_amount": "1.001"},
        {"name": "A", "limit_amount": "1.00", "color_hex": "#1234567890"},
        {"name": "A", "limit_amount": "1.00", "icon_code": "star"},
    ],
    ids=["no_name", "empty_name", "long_name", "no_limit", "3dp", "long_color", "bad_icon"],
)
def test_create_validation(api, payload):
    assert api.post("/budget/categories", payload).status_code == 422


def test_get_and_list(api, make):
    first = make.category(name="First")
    second = make.category(name="Second", category_type="income")
    assert make.get(f"/budget/categories/{second['id']}") == second
    assert make.get("/budget/categories") == [first, second]


@pytest.mark.parametrize(
    "field,value",
    [
        ("name", "Renamed"),
        ("limit_amount", "999.99"),
        ("category_type", "income"),
        ("icon_code", 1234),
        ("color_hex", "#000000"),
    ],
)
def test_patch_single_field(api, make, field, value):
    category = make.category(icon_code=1, color_hex="#FFFFFF")
    r = api.patch(f"/budget/categories/{category['id']}", {field: value})
    assert r.status_code == 200
    assert r.json() == {**category, field: value}


def test_patch_cannot_set_spent_amount(api, make):
    category = make.category()
    r = api.patch(f"/budget/categories/{category['id']}", {"spent_amount": "123.00"})
    assert r.json()["spent_amount"] == "0.00"


def test_patch_rejects_unknown_category_type(api, make):
    category = make.category()
    r = api.patch(f"/budget/categories/{category['id']}", {"category_type": "savings"})
    assert r.status_code == 422


def test_spent_amount_follows_expenses_after_type_flip(api, make):
    category = make.category(category_type="expense")
    make.expense(category["id"], amount="30.00")
    api.patch(f"/budget/categories/{category['id']}", {"category_type": "income"})
    # Later expenses use the new type's sign; earlier spend is not re-derived.
    make.expense(category["id"], amount="10.00")
    assert make.get(f"/budget/categories/{category['id']}")["spent_amount"] == "20.00"


def test_delete_cascades_expenses_and_restores_balances(api, make):
    account = make.account(balance="100.00")
    category = make.category()
    other = make.category(name="Other")
    doomed = make.expense(category["id"], amount="30.00", account_id=account["id"])
    kept = make.expense(other["id"], amount="5.00", account_id=account["id"])
    assert make.get(f"/accounts/{account['id']}")["balance"] == "65.00"

    assert api.delete(f"/budget/categories/{category['id']}").status_code == 204

    assert api.get(f"/budget/categories/{category['id']}").status_code == 404
    assert api.get(f"/expenses/{doomed['id']}").status_code == 404
    assert make.get(f"/expenses/{kept['id']}") == kept
    assert make.get(f"/accounts/{account['id']}")["balance"] == "95.00"


def test_delete_category_without_expenses(api, make):
    category = make.category()
    assert api.delete(f"/budget/categories/{category['id']}").status_code == 204
    assert make.get("/budget/categories") == []
