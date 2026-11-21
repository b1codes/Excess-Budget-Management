"""CORS for the Flutter web build.

Regression: CORS_ALLOWED_ORIGINS was parsed from the environment, but
django-cors-headers was never installed. Every browser preflight got a 405,
so the web app (served from S3 + CloudFront, a different origin from the API)
couldn't make a single request. Found by the E2E suite (CU-86bd3g3da).
"""

import pytest

ORIGIN = "https://app.example.com"


@pytest.fixture(autouse=True)
def _allowed_origin(settings):
    settings.CORS_ALLOWED_ORIGINS = [ORIGIN]


def _preflight(client, path, origin=ORIGIN, method="POST", headers="authorization,content-type"):
    return client.options(
        path,
        HTTP_ORIGIN=origin,
        HTTP_ACCESS_CONTROL_REQUEST_METHOD=method,
        HTTP_ACCESS_CONTROL_REQUEST_HEADERS=headers,
    )


@pytest.mark.parametrize(
    ("path", "method"),
    [
        ("/api/v1/auth/login", "POST"),
        ("/api/v1/auth/me", "GET"),
        ("/api/v1/accounts", "POST"),
        ("/api/v1/goals/00000000-0000-0000-0000-000000000000", "DELETE"),
    ],
)
def test_preflight_from_allowed_origin_succeeds(client, path, method):
    response = _preflight(client, path, method=method)

    assert response.status_code == 200
    assert response["Access-Control-Allow-Origin"] == ORIGIN
    assert method in response["Access-Control-Allow-Methods"]
    allowed_headers = response["Access-Control-Allow-Headers"].lower()
    assert "authorization" in allowed_headers
    assert "content-type" in allowed_headers


def test_preflight_from_other_origin_gets_no_cors_headers(client):
    response = _preflight(client, "/api/v1/auth/login", origin="https://evil.example.com")

    assert "Access-Control-Allow-Origin" not in response


def test_simple_request_from_allowed_origin_is_tagged(client):
    response = client.get("/api/v1/health", HTTP_ORIGIN=ORIGIN)

    assert response.status_code == 200
    assert response["Access-Control-Allow-Origin"] == ORIGIN


def test_no_origins_allowed_by_default(client, settings):
    settings.CORS_ALLOWED_ORIGINS = []

    response = client.get("/api/v1/health", HTTP_ORIGIN=ORIGIN)

    assert "Access-Control-Allow-Origin" not in response
