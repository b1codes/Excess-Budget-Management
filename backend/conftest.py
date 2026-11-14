"""
Root conftest.py.

Sets required env-vars and trims INSTALLED_APPS so the test suite can run
while later app packages are still being built in subsequent tasks.
"""

import os

# Must be set before Django loads settings (settings.py does os.environ["DJANGO_SECRET_KEY"])
os.environ.setdefault("DJANGO_SECRET_KEY", "test-only-secret-key-not-for-production")

import pytest
from django.test import Client
from apps.users.models import User
from apps.users.services import issue_tokens

import urllib.request


@pytest.fixture(scope="session", autouse=True)
def _require_firestore_emulator():
    if not os.environ.get("FIRESTORE_EMULATOR_HOST"):
        pytest.exit(
            "FIRESTORE_EMULATOR_HOST is not set. Start the emulator "
            "(`make up`, or `docker compose -f backend/docker-compose.yml up firestore`) "
            "before running tests.",
            returncode=1,
        )


@pytest.fixture(autouse=True)
def _wipe_firestore():
    from apps.common.firestore import get_client

    host = os.environ["FIRESTORE_EMULATOR_HOST"]
    project = get_client().project
    url = f"http://{host}/emulator/v1/projects/{project}/databases/(default)/documents"
    urllib.request.urlopen(urllib.request.Request(url, method="DELETE"))
    yield


@pytest.fixture
def user(db):
    return User.objects.create_user(email="alice@example.com", password="alicepass!")


@pytest.fixture
def other_user(db):
    return User.objects.create_user(email="bob@example.com", password="bobpass!!")


@pytest.fixture
def auth_client(user):
    tokens = issue_tokens(user)
    client = Client(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    return client, user


@pytest.fixture
def other_auth_client(other_user):
    tokens = issue_tokens(other_user)
    client = Client(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    return client, other_user


# --- JSON API helpers ---------------------------------------------------------
#
# Newer tests use `api` / `other_api` / `anon_api` plus the `make` factory
# instead of building requests by hand:
#
#     def test_rename(api, make):
#         account = make.account(balance="10.00")
#         r = api.patch(f"/accounts/{account['id']}", {"name": "Renamed"})
#         assert r.status_code == 200
#
# Paths are relative to /api/v1.

API_PREFIX = "/api/v1"


class JsonApi:
    """Thin JSON wrapper around Django's test Client, rooted at /api/v1."""

    def __init__(self, client: Client, user: User | None = None):
        self.client = client
        self.user = user

    def _url(self, path: str) -> str:
        return path if path.startswith(API_PREFIX) else f"{API_PREFIX}{path}"

    def get(self, path: str, params: dict | None = None):
        return self.client.get(self._url(path), params or {})

    def post(self, path: str, data: dict | None = None):
        return self.client.post(self._url(path), data or {}, content_type="application/json")

    def patch(self, path: str, data: dict | None = None):
        return self.client.patch(self._url(path), data or {}, content_type="application/json")

    def delete(self, path: str):
        return self.client.delete(self._url(path))


def _api_for(user: User) -> JsonApi:
    token = issue_tokens(user)["access"]
    return JsonApi(Client(HTTP_AUTHORIZATION=f"Bearer {token}"), user)


@pytest.fixture
def api(user) -> JsonApi:
    return _api_for(user)


@pytest.fixture
def other_api(other_user) -> JsonApi:
    return _api_for(other_user)


@pytest.fixture
def anon_api(db) -> JsonApi:
    return JsonApi(Client())


class Factory:
    """Creates resources through the public API (so every side effect runs) and
    returns the response JSON. `make.as_(other_api)` builds for another user."""

    def __init__(self, api: JsonApi):
        self.api = api

    def as_(self, api: JsonApi) -> "Factory":
        return Factory(api)

    def _create(self, path: str, data: dict) -> dict:
        r = self.api.post(path, data)
        assert r.status_code == 201, f"POST {path} -> {r.status_code}: {r.content!r}"
        return r.json()

    def account(self, name="Checking", balance="100.00") -> dict:
        return self._create("/accounts", {"name": name, "balance": balance})

    def category(self, name="Groceries", limit_amount="500.00", category_type="expense", **extra):
        data = {"name": name, "limit_amount": limit_amount, "category_type": category_type}
        return self._create("/budget/categories", {**data, **extra})

    def goal(self, name="Emergency fund", target_amount="1000.00", type="short_term", **extra):
        data = {"name": name, "target_amount": target_amount, "type": type}
        return self._create("/goals", {**data, **extra})

    def subgoal(self, goal_id, name="Part", target_amount="100.00", current_amount="0.00"):
        data = {"name": name, "target_amount": target_amount, "current_amount": current_amount}
        return self._create(f"/goals/{goal_id}/subgoals", data)

    def expense(self, budget_category_id, amount="10.00", date="2026-01-15", **extra):
        data = {"budget_category_id": budget_category_id, "amount": amount, "date": date}
        return self._create("/expenses", {**data, **extra})

    def extra_income(self, amount="50.00", date_received="2026-01-15", **extra):
        return self._create(
            "/income/extra", {"amount": amount, "date_received": date_received, **extra}
        )

    def income_source(self, name="Salary", expected_amount="3000.00", frequency="monthly"):
        data = {"name": name, "expected_amount": expected_amount, "frequency": frequency}
        return self._create("/income/sources", data)

    def allocation(self, goal_id, amount="25.00", **extra):
        return self._create("/allocations", {"goal_id": goal_id, "amount": amount, **extra})

    # Readers for asserting side effects.

    def get(self, path: str) -> dict:
        r = self.api.get(path)
        assert r.status_code == 200, f"GET {path} -> {r.status_code}: {r.content!r}"
        return r.json()


@pytest.fixture
def make(api) -> Factory:
    return Factory(api)
