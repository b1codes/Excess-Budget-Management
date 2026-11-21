"""Auth0 provider contract: /auth/auth0 against what Auth0 actually serves.

test_auth0_verification.py replaces the whole key lookup with a stub. Here
the real PyJWKClient fetches a JWKS document in Auth0's published format
(https://{domain}/.well-known/jwks.json, several RS256 keys during rotation,
each with kid/x5t/x5c), and tokens carry the claims Auth0 issues. Only the
HTTP fetch is faked, so a change in how the backend reads Auth0's keys or
tokens fails here.

Token shapes, per Auth0's docs:
* An access token for a custom API has `aud` as a list (the API identifier,
  plus /userinfo when `openid` was requested), `scope`, `azp`, and no
  profile claims such as email.
* An ID token has the profile claims, but `aud` is the application's client
  id, not the API identifier.
"""

import base64
import hashlib
import hmac
import io
import json
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from django.test import override_settings

from apps.users.models import User

pytestmark = pytest.mark.django_db

DOMAIN = "tenant.us.auth0.com"
ISSUER = f"https://{DOMAIN}/"
API_AUDIENCE = "https://api.excessbudget.example/"
CLIENT_ID = "vHX8TZc34HJfNRyA8aVZquT6509YnWUp"
JWKS_URL = f"https://{DOMAIN}/.well-known/jwks.json"

# Auth0 publishes the next signing key alongside the current one while
# rotating, so the backend has to pick by kid rather than take the first key.
CURRENT = rsa.generate_private_key(public_exponent=65537, key_size=2048)
NEXT = rsa.generate_private_key(public_exponent=65537, key_size=2048)
UNPUBLISHED = rsa.generate_private_key(public_exponent=65537, key_size=2048)


def _b64url_uint(n: int) -> str:
    raw = n.to_bytes((n.bit_length() + 7) // 8, "big")
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def _jwk(key, kid: str) -> dict:
    numbers = key.public_key().public_numbers()
    return {
        "kty": "RSA",
        "use": "sig",
        "alg": "RS256",
        "kid": kid,
        "n": _b64url_uint(numbers.n),
        "e": _b64url_uint(numbers.e),
        # Auth0 also sends the certificate chain and its thumbprint. Their
        # values don't matter to verification, but their presence must not
        # break parsing.
        "x5t": "Xh0Ywz6y6oPh8zQSVxGnLIKz4fA",
        "x5c": ["MIIDDTCCAfWgAwIBAgIJ"],
    }


JWKS = {"keys": [_jwk(CURRENT, "current-kid"), _jwk(NEXT, "next-kid")]}


class _Response(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()


@pytest.fixture
def auth0_tenant():
    """Production settings, with Auth0's JWKS endpoint answered locally."""
    fetched = []

    def urlopen(request, timeout=None, context=None):
        fetched.append(request.full_url)
        assert request.full_url == JWKS_URL
        return _Response(json.dumps(JWKS).encode())

    with (
        override_settings(AUTH0_DOMAIN=DOMAIN, AUTH0_AUDIENCE=API_AUDIENCE, DEBUG=False),
        patch("jwt.jwks_client.urllib.request.urlopen", urlopen),
    ):
        yield fetched


def _now():
    return datetime.now(timezone.utc)


def access_token_claims(**extra) -> dict:
    now = _now()
    return {
        "iss": ISSUER,
        "sub": "google-oauth2|103547991597142817347",
        "aud": [API_AUDIENCE, f"https://{DOMAIN}/userinfo"],
        "iat": now,
        "exp": now + timedelta(hours=24),
        "scope": "openid profile email",
        "azp": CLIENT_ID,
        **extra,
    }


def id_token_claims(**extra) -> dict:
    now = _now()
    return {
        "iss": ISSUER,
        "sub": "auth0|64f0c1a2b3c4d5e6f7a8b9c0",
        "aud": CLIENT_ID,
        "iat": now,
        "exp": now + timedelta(hours=10),
        "email": "ada@example.com",
        "email_verified": True,
        "name": "Ada Lovelace",
        "nickname": "ada",
        "picture": "https://s.gravatar.com/avatar/abc.png",
        "updated_at": "2026-11-20T10:00:00.000Z",
        "sid": "x1y2z3",
        "nonce": "n-0S6_WzA2Mj",
        **extra,
    }


def sign(claims: dict, key=CURRENT, kid="current-kid", algorithm="RS256") -> str:
    return jwt.encode(claims, key, algorithm=algorithm, headers={"kid": kid, "typ": "JWT"})


def login(anon_api, token):
    return anon_api.post("/auth/auth0", {"token": token})


# An access token with the user's email added under the standard claim name
# (e.g. by an Auth0 post-login Action). This is the shape the backend can use.
def email_access_token(**extra) -> dict:
    return access_token_claims(email="ada@example.com", name="Ada Lovelace", **extra)


def test_access_token_with_email_logs_in(auth0_tenant, anon_api):
    r = login(anon_api, sign(email_access_token()))

    assert r.status_code == 200, r.content
    assert r.json()["user"]["email"] == "ada@example.com"
    assert r.json()["user"]["full_name"] == "Ada Lovelace"
    assert auth0_tenant == [JWKS_URL]


def test_key_is_chosen_by_kid_during_rotation(auth0_tenant, anon_api):
    token = sign(email_access_token(), key=NEXT, kid="next-kid")
    assert login(anon_api, token).status_code == 200


@pytest.mark.parametrize(
    "token",
    [
        pytest.param(sign(email_access_token(), key=UNPUBLISHED, kid="gone"), id="unknown_kid"),
        pytest.param(sign(email_access_token(), key=NEXT, kid="current-kid"), id="wrong_key"),
        pytest.param(sign(email_access_token(iss=f"https://{DOMAIN}")), id="issuer_without_slash"),
        pytest.param(
            sign(email_access_token(aud=[f"https://{DOMAIN}/userinfo"])), id="other_audience"
        ),
        pytest.param(sign(email_access_token(exp=_now() - timedelta(seconds=1))), id="expired"),
    ],
)
def test_tokens_auth0_would_not_vouch_for_are_rejected(auth0_tenant, anon_api, token):
    assert login(anon_api, token).status_code == 401
    assert not User.objects.filter(email="ada@example.com").exists()


def test_hs256_signed_with_the_public_key_is_rejected(auth0_tenant, anon_api):
    # Algorithm confusion: an attacker who knows the public key signs with it
    # as an HMAC secret. Only RS256 may be accepted.
    public_pem = CURRENT.public_key().public_bytes(
        serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo
    )
    header = {"alg": "HS256", "kid": "current-kid", "typ": "JWT"}
    segments = [
        base64.urlsafe_b64encode(json.dumps(part, default=str).encode()).rstrip(b"=")
        for part in (header, {**email_access_token(), "iat": 0, "exp": 2**31})
    ]
    signing_input = b".".join(segments)
    signature = hmac.new(public_pem, signing_input, hashlib.sha256).digest()
    token = (signing_input + b"." + base64.urlsafe_b64encode(signature).rstrip(b"=")).decode()

    assert login(anon_api, token).status_code == 401


def test_id_token_is_rejected_because_its_audience_is_the_client_id(auth0_tenant, anon_api):
    # The ID token has the profile, but it's issued to the app, not the API.
    assert login(anon_api, sign(id_token_claims())).status_code == 401


@pytest.mark.xfail(
    strict=True,
    reason=(
        "CU-86bd3g3df: a default Auth0 access token has no email claim, so it can't "
        "log in. Needs an Auth0 Action that adds email to access tokens, or a "
        "/userinfo lookup on the backend."
    ),
)
def test_default_access_token_logs_in(auth0_tenant, anon_api):
    r = login(anon_api, sign(access_token_claims()))
    assert r.status_code == 200, r.content
