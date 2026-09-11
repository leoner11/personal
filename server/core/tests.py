"""⚠ These guard the things that, if wrong, hand the contact list and the
cashflow to whoever finds the host — and would look completely normal doing it.
Sync would sync. Nothing would error."""
import json

from django.contrib.auth.models import User
from django.core.cache import cache
from django.test import TestCase, override_settings

from core.auth import hash_token
from core.models import AuthToken

SECRET = "deploy-time-secret"


def body(response):
    return json.loads(response.content)


class RegistrationTests(TestCase):
    """⚠ The models have NO owner column: every row belongs to the deployment.
    A second account would not get its own data, it would get the first
    account's. Registration being closed is therefore not a policy, it is what
    makes the data model safe."""

    def post(self, payload, secret=SECRET):
        headers = {"X-Register-Secret": secret} if secret is not None else {}
        return self.client.post(
            "/auth/register",
            data=json.dumps(payload),
            content_type="application/json",
            headers=headers,
        )

    @override_settings(REGISTRATION_SECRET="")
    def test_registration_is_off_when_no_secret_is_configured(self):
        # ⚠ The default state. A fresh public server must not be a race between
        # the owner and whoever scans it first.
        r = self.post({"username": "leonard", "password": "a-long-passphrase-1"})
        self.assertEqual(r.status_code, 403)
        self.assertEqual(User.objects.count(), 0)

    @override_settings(REGISTRATION_SECRET=SECRET)
    def test_the_wrong_secret_is_refused(self):
        r = self.post({"username": "x", "password": "a-long-passphrase-1"}, secret="nope")
        self.assertEqual(r.status_code, 403)
        self.assertEqual(User.objects.count(), 0)

    @override_settings(REGISTRATION_SECRET=SECRET)
    def test_the_first_account_is_created_and_gets_a_token(self):
        r = self.post({"username": "leonard", "password": "a-long-passphrase-1"})
        self.assertEqual(r.status_code, 201)
        self.assertTrue(body(r)["token"])
        self.assertEqual(User.objects.count(), 1)

    @override_settings(REGISTRATION_SECRET=SECRET)
    def test_a_second_account_is_refused_even_with_the_right_secret(self):
        self.post({"username": "leonard", "password": "a-long-passphrase-1"})
        r = self.post({"username": "someone", "password": "a-long-passphrase-2"})
        self.assertEqual(r.status_code, 409)
        self.assertEqual(User.objects.count(), 1)

    @override_settings(REGISTRATION_SECRET=SECRET)
    def test_a_weak_password_is_refused(self):
        r = self.post({"username": "leonard", "password": "1234"})
        self.assertEqual(r.status_code, 400)
        self.assertEqual(User.objects.count(), 0)


@override_settings(REGISTRATION_SECRET="")
class LoginTests(TestCase):
    def setUp(self):
        cache.clear()  # the throttle is shared process state between tests
        self.user = User.objects.create_user("leonard", password="a-long-passphrase-1")

    def login(self, password):
        return self.client.post(
            "/auth/login",
            data=json.dumps({"username": "leonard", "password": password}),
            content_type="application/json",
        )

    def test_a_correct_password_returns_a_token(self):
        r = self.login("a-long-passphrase-1")
        self.assertEqual(r.status_code, 200)
        self.assertTrue(body(r)["token"])

    def test_a_wrong_password_is_rejected(self):
        self.assertEqual(self.login("wrong").status_code, 401)

    def test_the_error_does_not_say_which_half_was_wrong(self):
        # ⚠ Distinguishing them tells an attacker when they have found the
        # account and can stop guessing usernames.
        wrong_pw = body(self.login("wrong"))["detail"]
        r = self.client.post(
            "/auth/login",
            data=json.dumps({"username": "nobody", "password": "wrong"}),
            content_type="application/json",
        )
        self.assertEqual(wrong_pw, body(r)["detail"])

    def test_repeated_failures_are_throttled(self):
        # ⚠ A public login endpoint with no limit is a free password oracle.
        for _ in range(10):
            self.login("wrong")
        self.assertEqual(self.login("wrong").status_code, 429)
        # And the throttle holds even once the password is right.
        self.assertEqual(self.login("a-long-passphrase-1").status_code, 429)

    def test_the_raw_token_is_never_stored(self):
        raw = body(self.login("a-long-passphrase-1"))["token"]
        self.assertFalse(AuthToken.objects.filter(key_hash=raw).exists())
        self.assertTrue(AuthToken.objects.filter(key_hash=hash_token(raw)).exists())


@override_settings(REGISTRATION_SECRET="")
class ProtectedRouteTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user("leonard", password="a-long-passphrase-1")
        r = self.client.post(
            "/auth/login",
            data=json.dumps({"username": "leonard", "password": "a-long-passphrase-1"}),
            content_type="application/json",
        )
        self.token = body(r)["token"]

    def auth(self, value):
        return self.client.get("/sync", headers={"authorization": value})

    def test_sync_rejects_a_missing_token(self):
        self.assertEqual(self.client.get("/sync").status_code, 401)

    def test_sync_rejects_a_wrong_token(self):
        self.assertEqual(self.auth("Bearer nope").status_code, 401)

    def test_sync_rejects_the_right_token_under_the_wrong_scheme(self):
        self.assertEqual(self.auth(f"Basic {self.token}").status_code, 401)

    def test_sync_accepts_the_real_token(self):
        self.assertNotEqual(self.auth(f"Bearer {self.token}").status_code, 401)

    def test_signing_out_revokes_only_the_token_presented(self):
        # ⚠ Signing out the phone must not sign out the Mac.
        other = body(
            self.client.post(
                "/auth/login",
                data=json.dumps(
                    {"username": "leonard", "password": "a-long-passphrase-1"}
                ),
                content_type="application/json",
            )
        )["token"]
        self.client.post("/auth/logout", headers={"authorization": f"Bearer {self.token}"})
        self.assertEqual(self.auth(f"Bearer {self.token}").status_code, 401)
        self.assertNotEqual(self.auth(f"Bearer {other}").status_code, 401)

    def test_me_reports_the_account_behind_the_token(self):
        r = self.client.get("/auth/me", headers={"authorization": f"Bearer {self.token}"})
        self.assertEqual(body(r)["username"], "leonard")


@override_settings(REGISTRATION_SECRET="")
class AdminIsGoneTests(TestCase):
    def test_admin_is_unauthenticated_like_anything_else(self):
        # The middleware answers before routing, so it does not even confirm
        # whether the path exists.
        self.assertEqual(self.client.get("/admin/").status_code, 401)

    def test_admin_is_gone_even_to_a_valid_token(self):
        # ⚠ Removed, not hidden. It was a browser surface a bearer token cannot
        # guard, at a URL every scanner tries.
        User.objects.create_user("leonard", password="a-long-passphrase-1")
        token = body(
            self.client.post(
                "/auth/login",
                data=json.dumps(
                    {"username": "leonard", "password": "a-long-passphrase-1"}
                ),
                content_type="application/json",
            )
        )["token"]
        r = self.client.get("/admin/", headers={"authorization": f"Bearer {token}"})
        self.assertEqual(r.status_code, 404)

    def test_the_admin_app_is_not_installed(self):
        from django.conf import settings

        self.assertNotIn("django.contrib.admin", settings.INSTALLED_APPS)
