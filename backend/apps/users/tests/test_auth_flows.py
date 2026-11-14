"""Signup, login, refresh, /me and password reset edge cases not covered by
the per-endpoint happy-path tests."""

import time
from unittest.mock import patch

import pytest
from django.core import mail
from django.core.signing import TimestampSigner

from apps.users.models import Profile, User
from apps.users.tokens import make_reset_token

pytestmark = pytest.mark.django_db


# --- User model & manager -----------------------------------------------------------


def test_create_user_requires_email():
    with pytest.raises(ValueError, match="Email is required"):
        User.objects.create_user(email="", password="x")


def test_create_user_normalizes_email_domain():
    assert User.objects.create_user(email="Bob@EXAMPLE.COM", password="pw").email == (
        "Bob@example.com"
    )


def test_create_superuser_sets_flags():
    admin = User.objects.create_superuser(email="admin@example.com", password="pw")
    assert admin.is_staff and admin.is_superuser
    assert str(admin) == "admin@example.com"


def test_regular_user_is_not_staff(user):
    assert not user.is_staff and not user.is_superuser


# --- Signup / login / refresh -------------------------------------------------------


@pytest.mark.parametrize(
    "payload",
    [{"password": "longenough"}, {"email": "not-an-email", "password": "longenough"}],
    ids=["no_email", "bad_email"],
)
def test_signup_validation(anon_api, payload):
    assert anon_api.post("/auth/signup", payload).status_code == 422


def test_signup_creates_profile_with_defaults(anon_api):
    body = anon_api.post("/auth/signup", {"email": "new@example.com", "password": "longenough"})
    user = body.json()["user"]
    assert user["full_name"] == "" and user["default_savings_ratio"] == 0.5
    assert Profile.objects.filter(user__email="new@example.com").exists()


def test_login_unknown_email(anon_api):
    r = anon_api.post("/auth/login", {"email": "nobody@example.com", "password": "whatever"})
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "auth_error"


def test_login_inactive_user(anon_api, user):
    user.is_active = False
    user.save(update_fields=["is_active"])
    r = anon_api.post("/auth/login", {"email": user.email, "password": "alicepass!"})
    assert r.status_code == 401


def test_login_response_includes_user(anon_api, user):
    body = anon_api.post("/auth/login", {"email": user.email, "password": "alicepass!"}).json()
    assert body["user"]["id"] == str(user.id)
    assert body["access"] and body["refresh"]


@pytest.mark.parametrize("token", ["garbage", "access"], ids=["garbage", "access_as_refresh"])
def test_refresh_rejects_non_refresh_tokens(anon_api, user, token):
    if token == "access":
        token = anon_api.post(
            "/auth/login", {"email": user.email, "password": "alicepass!"}
        ).json()["access"]
    assert anon_api.post("/auth/refresh", {"refresh": token}).status_code == 401


def test_refreshed_access_token_works(anon_api, user):
    tokens = anon_api.post("/auth/login", {"email": user.email, "password": "alicepass!"}).json()
    new = anon_api.post("/auth/refresh", {"refresh": tokens["refresh"]}).json()
    anon_api.client.defaults["HTTP_AUTHORIZATION"] = f"Bearer {new['access']}"
    assert anon_api.get("/auth/me").json()["email"] == user.email


# --- /me ----------------------------------------------------------------------------


def test_me_without_profile_returns_defaults(api, user):
    assert not Profile.objects.filter(user=user).exists()
    body = api.get("/auth/me").json()
    assert body["full_name"] == "" and body["avatar_url"] == ""
    assert body["default_savings_ratio"] == 0.5


def test_patch_me_creates_profile_and_is_partial(api, user):
    api.patch("/auth/me", {"full_name": "Alice"})
    body = api.patch("/auth/me", {"default_savings_ratio": 0.8}).json()
    assert body["full_name"] == "Alice"
    assert body["default_savings_ratio"] == 0.8
    assert Profile.objects.get(user=user).full_name == "Alice"


@pytest.mark.parametrize("ratio", [-0.01, 1.01])
def test_patch_me_ratio_bounds(api, ratio):
    assert api.patch("/auth/me", {"default_savings_ratio": ratio}).status_code == 422


@pytest.mark.parametrize("ratio", [0, 1])
def test_patch_me_ratio_edges_are_allowed(api, ratio):
    assert api.patch("/auth/me", {"default_savings_ratio": ratio}).json()[
        "default_savings_ratio"
    ] == float(ratio)


# --- Password reset -----------------------------------------------------------------


def test_reset_request_emails_a_working_link(anon_api, user):
    assert anon_api.post("/auth/password-reset/request", {"email": user.email}).status_code == 204

    [message] = mail.outbox
    assert message.to == [user.email]
    token = message.body.split("token=")[1].split()[0]
    r = anon_api.post(
        "/auth/password-reset/confirm", {"token": token, "new_password": "brand-new-pass"}
    )
    assert r.status_code == 204
    assert (
        anon_api.post(
            "/auth/login", {"email": user.email, "password": "brand-new-pass"}
        ).status_code
        == 200
    )
    assert (
        anon_api.post("/auth/login", {"email": user.email, "password": "alicepass!"}).status_code
        == 401
    )


def test_reset_request_matches_email_case_insensitively(anon_api, user):
    anon_api.post("/auth/password-reset/request", {"email": user.email.upper()})
    assert len(mail.outbox) == 1


def test_reset_request_for_unknown_email_sends_nothing(anon_api):
    assert (
        anon_api.post("/auth/password-reset/request", {"email": "nobody@example.com"}).status_code
        == 204
    )
    assert mail.outbox == []


def test_reset_token_expires_after_an_hour(anon_api, user):
    token = make_reset_token(user.id)
    an_hour_later = time.time() + 3601
    with patch("django.core.signing.time.time", return_value=an_hour_later):
        r = anon_api.post(
            "/auth/password-reset/confirm", {"token": token, "new_password": "brand-new-pass"}
        )
    assert r.status_code == 401


def test_reset_token_for_deleted_user(anon_api, user):
    token = make_reset_token(user.id)
    user.delete()
    r = anon_api.post(
        "/auth/password-reset/confirm", {"token": token, "new_password": "brand-new-pass"}
    )
    assert r.status_code == 401


def test_reset_token_signed_for_another_purpose_is_rejected(anon_api, user):
    # Same SECRET_KEY, different salt: must not be accepted as a reset token.
    token = TimestampSigner(salt="something-else").sign(str(user.id))
    r = anon_api.post(
        "/auth/password-reset/confirm", {"token": token, "new_password": "brand-new-pass"}
    )
    assert r.status_code == 401


def test_reset_confirm_validates_new_password(anon_api, user):
    r = anon_api.post(
        "/auth/password-reset/confirm",
        {"token": make_reset_token(user.id), "new_password": "short"},
    )
    assert r.status_code == 422


def test_patch_me_avatar_url(api):
    body = api.patch("/auth/me", {"avatar_url": "https://example.com/me.png"}).json()
    assert body["avatar_url"] == "https://example.com/me.png"
