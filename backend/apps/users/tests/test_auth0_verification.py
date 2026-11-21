"""Auth0 token verification.

With AUTH0_DOMAIN set and DEBUG off (production), tokens must be RS256 and
verified against the tenant's JWKS, audience and issuer. The JWKS fetch is
mocked with a locally generated key pair.

The dev-mode fallback (no AUTH0_DOMAIN, or DEBUG on) skips signature checks.
That's tracked by the Security subtask (CU-86bd3g3df). The strict xfails at
the bottom record it and will fail loudly once it's fixed, so the markers get
removed.
"""

from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from django.conf import settings
from django.test import override_settings

from apps.users.models import Profile, User

pytestmark = pytest.mark.django_db

DOMAIN = "tenant.example.com"
AUDIENCE = "https://api.example.com"
ISSUER = f"https://{DOMAIN}/"

_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
_OTHER_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)


def _claims(**overrides):
    now = datetime.now(timezone.utc)
    claims = {
        "email": "auth0-user@example.com",
        "name": "Auth0 User",
        "picture": "https://example.com/p.png",
        "aud": AUDIENCE,
        "iss": ISSUER,
        "iat": now,
        "exp": now + timedelta(minutes=5),
    }
    claims.update(overrides)
    return {k: v for k, v in claims.items() if v is not None}


def _rs256(key=_KEY, **overrides) -> str:
    return jwt.encode(_claims(**overrides), key, algorithm="RS256", headers={"kid": "k1"})


@pytest.fixture
def production_auth0():
    """AUTH0_DOMAIN set, DEBUG off, and a JWKS that serves _KEY's public half."""

    class _JWKS:
        def __init__(self, url):
            assert url == f"https://{DOMAIN}/.well-known/jwks.json"

        def get_signing_key_from_jwt(self, token):
            return type("SigningKey", (), {"key": _KEY.public_key()})()

    with (
        override_settings(AUTH0_DOMAIN=DOMAIN, AUTH0_AUDIENCE=AUDIENCE, DEBUG=False),
        patch("jwt.PyJWKClient", _JWKS),
    ):
        yield


def _login(anon_api, token):
    return anon_api.post("/auth/auth0", {"token": token})


def test_valid_rs256_token_logs_in(production_auth0, anon_api):
    r = _login(anon_api, _rs256())
    assert r.status_code == 200, r.content
    assert r.json()["user"]["email"] == "auth0-user@example.com"
    assert User.objects.filter(email="auth0-user@example.com").exists()


@pytest.mark.parametrize(
    "token",
    [
        lambda: _rs256(key=_OTHER_KEY),
        lambda: _rs256(aud="https://someone-else.example.com"),
        lambda: _rs256(aud=None),
        lambda: _rs256(iss="https://evil.example.com/"),
        lambda: _rs256(exp=datetime.now(timezone.utc) - timedelta(seconds=1)),
        lambda: jwt.encode(_claims(), settings.SECRET_KEY, algorithm="HS256"),
        lambda: jwt.encode(_claims(), None, algorithm="none"),
        lambda: "not-a-jwt",
    ],
    ids=[
        "wrong_key",
        "wrong_audience",
        "no_audience",
        "wrong_issuer",
        "expired",
        "hs256_with_secret_key",
        "unsigned",
        "garbage",
    ],
)
def test_production_rejects_unverifiable_tokens(production_auth0, anon_api, token):
    r = _login(anon_api, token())
    assert r.status_code == 401
    assert not User.objects.filter(email="auth0-user@example.com").exists()


def test_token_without_email_is_rejected(production_auth0, anon_api):
    r = _login(anon_api, _rs256(email=None))
    assert r.status_code == 401
    assert "email" in r.json()["error"]["message"]


def test_existing_profile_is_backfilled_not_overwritten(production_auth0, anon_api, user):
    Profile.objects.create(user=user, full_name="Alice", avatar_url="")
    r = _login(anon_api, _rs256(email=user.email, name="Someone Else", picture="https://x/y.png"))
    assert r.status_code == 200
    user.profile.refresh_from_db()
    assert user.profile.full_name == "Alice"
    assert user.profile.avatar_url == "https://x/y.png"


def test_existing_user_without_profile_gets_one(production_auth0, anon_api, user):
    r = _login(anon_api, _rs256(email=user.email, name="Alice"))
    assert r.status_code == 200
    assert Profile.objects.get(user=user).full_name == "Alice"


def test_nickname_is_used_when_name_is_missing(production_auth0, anon_api):
    _login(anon_api, _rs256(name=None, nickname="ace"))
    assert User.objects.get(email="auth0-user@example.com").profile.full_name == "ace"


def test_new_auth0_user_cannot_use_password_login(production_auth0, anon_api):
    _login(anon_api, _rs256())
    r = anon_api.post("/auth/login", {"email": "auth0-user@example.com", "password": ""})
    assert r.status_code in (401, 422)


# --- Known gaps (Security subtask CU-86bd3g3df) --------------------------------------


@pytest.mark.xfail(
    strict=True,
    reason="CU-86bd3g3df: with AUTH0_DOMAIN unset, signature verification is skipped",
)
@override_settings(AUTH0_DOMAIN="", DEBUG=False)
def test_unsigned_token_is_rejected_even_without_auth0_domain(anon_api, user):
    forged = jwt.encode({"email": user.email}, None, algorithm="none")
    assert _login(anon_api, forged).status_code == 401


@pytest.mark.xfail(
    strict=True,
    reason="CU-86bd3g3df: email_verified isn't checked before matching an existing account",
)
def test_unverified_email_cannot_take_over_an_existing_account(production_auth0, anon_api, user):
    r = _login(anon_api, _rs256(email=user.email, email_verified=False))
    assert r.status_code == 401
