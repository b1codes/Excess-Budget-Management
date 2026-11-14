"""Route-inventory contract tests.

These walk every operation registered on the ninja API (via its OpenAPI
schema), so a new endpoint is covered automatically and can't ship without
auth or ownership checks by accident:

* every non-public route rejects missing, malformed, expired, wrong-type and
  revoked-user tokens with 401;
* the set of public routes is an explicit allowlist;
* every route that addresses a resource by id returns 404 (not 403, not the
  data) for another user's resource and for unknown ids, and leaves the
  owner's data untouched.
"""

import re
import uuid
from datetime import timedelta

import pytest
from django.test import Client
from ninja_jwt.tokens import AccessToken, RefreshToken

from config.api import api as ninja_api

PREFIX = "/api/v1/"

PUBLIC_ROUTES = {
    ("GET", "/api/v1/health"),
    ("POST", "/api/v1/auth/signup"),
    ("POST", "/api/v1/auth/login"),
    ("POST", "/api/v1/auth/auth0"),
    ("POST", "/api/v1/auth/refresh"),
    ("POST", "/api/v1/auth/password-reset/request"),
    ("POST", "/api/v1/auth/password-reset/confirm"),
}


def _operations():
    schema = ninja_api.get_openapi_schema(path_prefix=PREFIX)
    for path, ops in schema["paths"].items():
        for method, op in ops.items():
            yield method.upper(), path, bool(op.get("security"))


ALL_ROUTES = sorted((m, p) for m, p, _ in _operations())
SECURED_ROUTES = sorted((m, p) for m, p, secured in _operations() if secured)
PARAM_ROUTES = sorted((m, p) for m, p in ALL_ROUTES if "{" in p)


def _fill(path: str, value: str = None) -> str:
    return re.sub(r"\{[^}]+\}", lambda _: value or str(uuid.uuid4()), path)


def _call(client: Client, method: str, path: str, data: dict | None = None):
    fn = getattr(client, method.lower())
    if method in ("POST", "PATCH", "PUT"):
        return fn(path, data or {}, content_type="application/json")
    return fn(path)


def test_public_routes_are_exactly_the_allowlist():
    public = {(m, p) for m, p, secured in _operations() if not secured}
    assert public == PUBLIC_ROUTES, (
        "Public (unauthenticated) routes changed. If this is intended, update "
        "PUBLIC_ROUTES; otherwise add auth=JWTAuth() to the router or operation."
    )


def test_inventory_is_not_empty():
    # Guards against the schema lookup silently returning nothing, which would
    # make every parametrized test below vacuous.
    assert len(SECURED_ROUTES) > 40


# --- Authentication -------------------------------------------------------------


def _bearer(token: str) -> Client:
    return Client(HTTP_AUTHORIZATION=f"Bearer {token}")


def _expired_access_token(user) -> str:
    token = AccessToken.for_user(user)
    token.set_exp(lifetime=-timedelta(seconds=1))
    return str(token)


BAD_CREDENTIALS = {
    "no_header": lambda user: Client(),
    "malformed_token": lambda user: _bearer("not-a-jwt"),
    "wrong_scheme": lambda user: Client(HTTP_AUTHORIZATION=f"Token {AccessToken.for_user(user)}"),
    "expired_token": lambda user: _bearer(_expired_access_token(user)),
    "refresh_token_as_access": lambda user: _bearer(str(RefreshToken.for_user(user))),
    "tampered_signature": lambda user: _bearer(str(AccessToken.for_user(user))[:-4] + "AAAA"),
}


@pytest.mark.django_db
@pytest.mark.parametrize("method,path", SECURED_ROUTES)
@pytest.mark.parametrize("credential", sorted(BAD_CREDENTIALS))
def test_secured_route_rejects_bad_credentials(user, method, path, credential):
    client = BAD_CREDENTIALS[credential](user)
    r = _call(client, method, _fill(path))
    assert r.status_code == 401, f"{credential}: {method} {path} -> {r.status_code}"


@pytest.mark.django_db
@pytest.mark.parametrize("method,path", SECURED_ROUTES)
def test_secured_route_rejects_token_for_deleted_user(user, method, path):
    client = _bearer(str(AccessToken.for_user(user)))
    user.delete()
    assert _call(client, method, _fill(path)).status_code == 401


@pytest.mark.django_db
@pytest.mark.parametrize("method,path", SECURED_ROUTES)
def test_secured_route_rejects_token_for_inactive_user(user, method, path):
    client = _bearer(str(AccessToken.for_user(user)))
    user.is_active = False
    user.save(update_fields=["is_active"])
    assert _call(client, method, _fill(path)).status_code == 401


# --- Ownership / isolation ------------------------------------------------------


@pytest.fixture
def owned(make):
    """One of every resource, owned by `user`. Keys match path parameter names."""
    account = make.account()
    category = make.category()
    goal = make.goal()
    subgoal = make.subgoal(goal["id"])
    make.expense(category["id"], account_id=account["id"])
    make.api.post(f"/goals/{goal['id']}/accounts", {"account_id": account["id"]})
    return {
        "account_id": account["id"],
        "category_id": category["id"],
        "goal_id": goal["id"],
        "sid": subgoal["id"],
        "expense_id": make.expense(category["id"])["id"],
        "extra_id": make.extra_income(account_id=account["id"])["id"],
        "source_id": make.income_source()["id"],
        "allocation_id": make.allocation(goal["id"], account_id=account["id"])["id"],
    }


# A body that passes schema validation for each route that takes one, so a
# 404 can't be masked by a 422.
VALID_BODIES = {
    ("PATCH", "/api/v1/accounts/{account_id}"): {"name": "hijacked"},
    ("PATCH", "/api/v1/budget/categories/{category_id}"): {"name": "hijacked"},
    ("PATCH", "/api/v1/goals/{goal_id}"): {"name": "hijacked"},
    ("POST", "/api/v1/goals/{goal_id}/subgoals"): {"name": "x", "target_amount": "1.00"},
    ("PATCH", "/api/v1/goals/{goal_id}/subgoals/{sid}"): {"name": "hijacked"},
    ("POST", "/api/v1/goals/{goal_id}/accounts"): {"account_id": str(uuid.uuid4())},
    ("PATCH", "/api/v1/expenses/{expense_id}"): {"description": "hijacked"},
    ("PATCH", "/api/v1/income/sources/{source_id}"): {"name": "hijacked"},
    ("PATCH", "/api/v1/income/extra/{extra_id}"): {"description": "hijacked"},
    ("PATCH", "/api/v1/allocations/{allocation_id}"): {"amount": "999.00"},
}


def test_every_param_route_with_a_body_has_a_valid_body():
    needs_body = {(m, p) for m, p in PARAM_ROUTES if m in ("POST", "PATCH", "PUT")}
    assert needs_body == set(VALID_BODIES), "Update VALID_BODIES for new/removed routes."


def _resolve(path: str, ids: dict) -> str:
    return re.sub(r"\{([^}]+)\}", lambda m: ids[m.group(1)], path)


def _snapshot(api) -> dict:
    """Everything `user` can see, to prove a failed cross-user call changed nothing."""
    paths = [
        "/accounts",
        "/budget/categories",
        "/goals",
        "/expenses",
        "/income/sources",
        "/income/extra",
        "/allocations",
    ]
    state = {p: api.get(p).json() for p in paths}
    for goal in state["/goals"]:
        state[f"/goals/{goal['id']}/subgoals"] = api.get(f"/goals/{goal['id']}/subgoals").json()
    return state


@pytest.mark.django_db
@pytest.mark.parametrize("method,path", PARAM_ROUTES)
def test_other_users_resource_is_not_found_and_untouched(api, other_api, owned, method, path):
    before = _snapshot(api)
    body = VALID_BODIES.get((method, path))
    if path.endswith("/accounts") and method == "POST":
        # Link the owner's account to the owner's goal, as the attacker.
        body = {"account_id": owned["account_id"]}

    r = _call(other_api.client, method, _resolve(path, owned), body)

    assert r.status_code == 404, f"{method} {path} -> {r.status_code}: {r.content!r}"
    assert r.json()["error"]["code"] == "not_found"
    assert _snapshot(api) == before


@pytest.mark.django_db
@pytest.mark.parametrize("method,path", PARAM_ROUTES)
@pytest.mark.parametrize("bad_id", ["random_uuid", "not_a_uuid"])
def test_unknown_id_is_not_found(api, owned, method, path, bad_id):
    # Swap the *last* path parameter for a bad id, keeping any parent ids valid,
    # so nested routes are checked at the innermost level too.
    names = re.findall(r"\{([^}]+)\}", path)
    ids = {**owned, names[-1]: str(uuid.uuid4()) if bad_id == "random_uuid" else "not-a-uuid"}
    body = VALID_BODIES.get((method, path))

    r = _call(api.client, method, _resolve(path, ids), body)

    assert r.status_code == 404, f"{method} {path} -> {r.status_code}: {r.content!r}"
