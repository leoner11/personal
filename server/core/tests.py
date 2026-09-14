"""⚠ These guard the things that, if wrong, hand the contact list and the
cashflow to whoever finds the host — and would look completely normal doing it.
Sync would sync. Nothing would error."""
import json

from django.contrib.auth.models import User
from django.core.cache import cache
from django.test import TestCase, override_settings

from core.auth import hash_token
from core.models import AuthToken, Person

SECRET = "deploy-time-secret"


def body(response):
    return json.loads(response.content)


class RegistrationTests(TestCase):
    def setUp(self):
        cache.clear()

    def post(self, payload, secret=None):
        headers = {"X-Register-Secret": secret} if secret else {}
        return self.client.post(
            "/auth/register",
            data=json.dumps(payload),
            content_type="application/json",
            headers=headers,
        )

    @override_settings(REGISTRATION_SECRET="")
    def test_signup_is_open_when_no_secret_is_configured(self):
        r = self.post({"username": "leonard", "password": "a-long-passphrase-1"})
        self.assertEqual(r.status_code, 201)
        self.assertTrue(body(r)["token"])

    @override_settings(REGISTRATION_SECRET="")
    def test_a_second_account_is_allowed(self):
        self.post({"username": "leonard", "password": "a-long-passphrase-1"})
        r = self.post({"username": "sri", "password": "a-long-passphrase-2"})
        self.assertEqual(r.status_code, 201)
        self.assertEqual(User.objects.count(), 2)

    @override_settings(REGISTRATION_SECRET="")
    def test_a_duplicate_username_is_refused(self):
        self.post({"username": "leonard", "password": "a-long-passphrase-1"})
        r = self.post({"username": "leonard", "password": "a-long-passphrase-2"})
        self.assertEqual(r.status_code, 409)
        self.assertEqual(User.objects.count(), 1)

    @override_settings(REGISTRATION_SECRET=SECRET)
    def test_the_secret_closes_signup_when_set(self):
        self.assertEqual(self.post({"username": "x", "password": "a-long-passphrase-1"}).status_code, 403)
        r = self.post({"username": "x", "password": "a-long-passphrase-1"}, secret=SECRET)
        self.assertEqual(r.status_code, 201)

    @override_settings(REGISTRATION_SECRET="")
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


@override_settings(REGISTRATION_SECRET="")
class TenantIsolationTests(TestCase):
    """⚠ THE TESTS THIS WHOLE CHANGE EXISTS FOR.

    The clients generate their own primary keys, so a row id is a guessable
    claim rather than a secret — and seeded occasion ids are deliberately
    IDENTICAL on every device and therefore across accounts too. If ownership
    were enforced by a check in a view instead of by the database, one forgotten
    filter would hand one account's contacts and cashflow to another, silently,
    while sync carried on looking perfectly healthy."""

    def setUp(self):
        cache.clear()
        self.a = self.account("leonard")
        self.b = self.account("sri")

    def account(self, username):
        r = self.client.post(
            "/auth/register",
            data=json.dumps({"username": username, "password": "a-long-passphrase-1"}),
            content_type="application/json",
        )
        return body(r)["token"]

    def push(self, token, rows):
        return self.client.post(
            "/sync",
            data=json.dumps({"tables": {"people": rows}}),
            content_type="application/json",
            headers={"authorization": f"Bearer {token}"},
        )

    def pull(self, token):
        r = self.client.get("/sync", headers={"authorization": f"Bearer {token}"})
        return json.loads(r.content)["tables"]["people"]

    def test_a_row_pushed_by_one_account_is_invisible_to_the_other(self):
        self.push(self.a, [{"id": "row-1", "name": "Pak Andi"}])
        self.assertEqual([p["name"] for p in self.pull(self.a)], ["Pak Andi"])
        self.assertEqual(self.pull(self.b), [])

    def test_one_account_cannot_overwrite_another_row_by_reusing_its_id(self):
        # ⚠ The attack the old code was open to: update_or_create(id=pk) with
        # no owner in the lookup found the other account's row and overwrote it.
        self.push(self.a, [{"id": "row-1", "name": "Pak Andi"}])
        self.push(self.b, [{"id": "row-1", "name": "Hijacked"}])

        self.assertEqual([p["name"] for p in self.pull(self.a)], ["Pak Andi"])
        self.assertEqual([p["name"] for p in self.pull(self.b)], ["Hijacked"])

    def test_both_accounts_can_hold_the_same_seeded_occasion_id(self):
        # ⚠ Not a hypothetical. seededId() in the Dart is a UUID v5 of
        # name+date, so every device on earth derives the SAME id for 中秋节
        # 2026. Globally unique ids would make the second account's entire
        # festival calendar collide and vanish.
        seeded = "b1946ac9-2492-4c1e-9e10-0fa71e1f9f7f"
        for token in (self.a, self.b):
            r = self.client.post(
                "/sync",
                data=json.dumps(
                    {"tables": {"occasions": [
                        {"id": seeded, "name": "中秋节", "date": "2026-09-25T00:00:00Z",
                         "tag": "midAutumn"}
                    ]}}
                ),
                content_type="application/json",
                headers={"authorization": f"Bearer {token}"},
            )
            self.assertEqual(r.status_code, 200)

        for token in (self.a, self.b):
            r = self.client.get("/sync", headers={"authorization": f"Bearer {token}"})
            rows = json.loads(r.content)["tables"]["occasions"]
            self.assertEqual([o["id"] for o in rows], [seeded])

    def test_a_row_with_no_owner_is_returned_to_nobody(self):
        # ⚠ Fail closed. If a bug ever creates an ownerless row it must be
        # invisible, not public.
        Person.objects.create(client_id="orphan", name="Nobody", owner=None)
        self.assertEqual(self.pull(self.a), [])
        self.assertEqual(self.pull(self.b), [])

    def test_deleting_an_account_takes_its_rows_with_it(self):
        self.push(self.a, [{"id": "row-1", "name": "Pak Andi"}])
        User.objects.get(username="leonard").delete()
        self.assertEqual(Person.objects.filter(client_id="row-1").count(), 0)


@override_settings(REGISTRATION_SECRET="")
class TaskSyncTests(TestCase):
    """Tasks ride the same sync as every other table. ⚠ due_date, done_at and
    created_at are datetimes, so each must be parsed on push — a raw string
    stored in a DateTimeField is the class of bug that moved a meeting eight
    hours."""

    def setUp(self):
        cache.clear()
        r = self.client.post(
            "/auth/register",
            data=json.dumps({"username": "leonard", "password": "a-long-passphrase-1"}),
            content_type="application/json",
        )
        self.auth = {"authorization": f"Bearer {body(r)['token']}"}

    def test_a_task_round_trips_with_its_dates(self):
        self.client.post(
            "/sync",
            data=json.dumps({"tables": {"tasks": [{
                "id": "t1", "title": "Send the quotation", "notes": "",
                "created_at": "2026-09-13T02:00:00Z",
                "due_date": "2026-09-17T16:00:00Z",
                "done_at": None, "person_id": "p1", "engagement_id": "",
            }]}}),
            content_type="application/json",
            headers=self.auth,
        )
        rows = json.loads(
            self.client.get("/sync", headers=self.auth).content)["tables"]["tasks"]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["title"], "Send the quotation")
        self.assertEqual(rows[0]["due_date"], "2026-09-17T16:00:00+00:00")
        self.assertIsNone(rows[0]["done_at"])
        self.assertEqual(rows[0]["person_id"], "p1")

    def test_ticking_off_on_one_device_reaches_the_other(self):
        row = {"id": "t1", "title": "Call Pak Budi", "created_at": "2026-09-13T02:00:00Z"}
        for done in (None, "2026-09-14T03:00:00Z"):
            self.client.post(
                "/sync",
                data=json.dumps({"tables": {"tasks": [dict(row, done_at=done)]}}),
                content_type="application/json",
                headers=self.auth,
            )
        rows = json.loads(
            self.client.get("/sync", headers=self.auth).content)["tables"]["tasks"]
        self.assertEqual([r["done_at"] for r in rows], ["2026-09-14T03:00:00+00:00"])
