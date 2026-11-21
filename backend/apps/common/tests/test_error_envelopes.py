"""The error bodies the API sends, which the client's ApiClient parses
(frontend/test/contract/error_envelope_contract_test.dart uses the same shapes).
They aren't in openapi.json, so they're pinned here instead.

* Errors raised by the app: {"error": {"code", "message", "details"}}
* Request validation (ninja): 422 {"detail": [{"type", "loc", "msg", ...}]}
* Missing or bad credentials (ninja): 401 {"detail": "Unauthorized"}
"""

from unittest.mock import patch

import pytest

from apps.common.exceptions import UpstreamError

pytestmark = pytest.mark.django_db


def _assert_app_error(r, status, code):
    assert r.status_code == status
    body = r.json()
    assert set(body) == {"error"}
    assert set(body["error"]) == {"code", "message", "details"}
    assert body["error"]["code"] == code
    assert isinstance(body["error"]["message"], str) and body["error"]["message"]


def test_not_found(api):
    _assert_app_error(api.get("/goals/00000000-0000-0000-0000-000000000000"), 404, "not_found")


def test_conflict(anon_api, user):
    r = anon_api.post("/auth/signup", {"email": user.email, "password": "longenough1!"})
    _assert_app_error(r, 409, "conflict")


def test_auth_error(anon_api, user):
    r = anon_api.post("/auth/login", {"email": user.email, "password": "wrong-password"})
    _assert_app_error(r, 401, "auth_error")


def test_upstream_error_keeps_details(api):
    with patch(
        "apps.suggestions.services.call_gemini",
        side_effect=UpstreamError("down", details={"why": "quota"}),
    ):
        r = api.post("/suggestions/generate", {"excess_funds": "1.00"})
    _assert_app_error(r, 502, "upstream_error")
    assert r.json()["error"]["details"] == {"why": "quota"}


def test_request_validation(api):
    r = api.post("/accounts", {"balance": "not money"})
    assert r.status_code == 422
    detail = r.json()["detail"]
    assert isinstance(detail, list) and detail
    for item in detail:
        assert {"type", "loc", "msg"} <= set(item)
        assert isinstance(item["msg"], str)


def test_missing_credentials(anon_api):
    r = anon_api.get("/accounts")
    assert r.status_code == 401
    assert r.json() == {"detail": "Unauthorized"}
