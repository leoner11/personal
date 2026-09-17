"""⚠ These guard the things that, if wrong, hand the contact list and the
cashflow to whoever finds the host — and would look completely normal doing it.
Sync would sync. Nothing would error."""
import json

from django.contrib.auth.models import User
from django.core.cache import cache
from django.test import TestCase, override_settings

from core.auth import hash_token
from core.models import AuthToken, OccasionTag, Person

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


class OccasionTagSyncTests(TestCase):
    """The tag vocabulary rides the same sync as every other table.

    ⚠ IT HAS TO. The tags are what a person's occasion_tags, an occasion's tag
    and a money row's occasion_tag all point AT, by slug. A vocabulary that
    stayed on one device would leave the other showing raw slugs it cannot
    resolve, on chips it cannot offer — the person would be tagged with
    something the Mac has no way to display or untick."""

    def setUp(self):
        cache.clear()
        r = self.client.post(
            "/auth/register",
            data=json.dumps({"username": "leonard", "password": "a-long-passphrase-1"}),
            content_type="application/json",
        )
        self.auth = {"authorization": f"Bearer {body(r)['token']}"}

    def push(self, rows):
        return self.client.post(
            "/sync",
            data=json.dumps({"tables": {"occasion_tags": rows}}),
            content_type="application/json",
            headers=self.auth,
        )

    def pull(self):
        return json.loads(
            self.client.get("/sync", headers=self.auth).content
        )["tables"]["occasion_tags"]

    def test_a_tag_round_trips_with_everything_the_chip_needs(self):
        self.push([{
            "id": "tag-1", "slug": "hanukkah", "label": "Hanukkah",
            "hint": "Jewish contacts", "greeting": "Happy Hanukkah!",
            "sort_order": 9, "built_in": False,
        }])
        rows = self.pull()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["slug"], "hanukkah")
        self.assertEqual(rows[0]["label"], "Hanukkah")
        self.assertEqual(rows[0]["greeting"], "Happy Hanukkah!")
        self.assertEqual(rows[0]["sort_order"], 9)
        self.assertFalse(rows[0]["built_in"])

    def test_a_rename_reaches_the_other_device_without_moving_the_slug(self):
        # ⚠ The slug is the join key. If a rename changed it, every person
        # already carrying the tag would detach silently.
        for label in ("Lebaran / Aidilfitri", "Raya"):
            self.push([{
                "id": "tag-2", "slug": "lebaran", "label": label,
                "built_in": True, "sort_order": 0,
            }])
        rows = self.pull()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["label"], "Raya")
        self.assertEqual(rows[0]["slug"], "lebaran")

    def test_a_deleted_tag_syncs_as_deleted_rather_than_vanishing(self):
        # A hard delete would leave nothing to tell the other device it is
        # gone, and the tag would sync straight back on its next push.
        self.push([{"id": "tag-3", "slug": "guoqing", "label": "National Day"}])
        self.push([{
            "id": "tag-3", "slug": "guoqing", "label": "National Day",
            "deleted_at": "2026-09-17T02:00:00Z",
        }])
        rows = self.pull()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["deleted_at"], "2026-09-17T02:00:00+00:00")

    def test_the_two_accounts_can_hold_the_same_seeded_tag_id(self):
        # Seeded tag ids are a v5 hash of the slug, so they are identical on
        # every device AND across accounts. Uniqueness is scoped to the owner;
        # globally unique would make the second user's vocabulary collide with
        # the first's and vanish.
        r = self.client.post(
            "/auth/register",
            data=json.dumps({"username": "sri", "password": "a-long-passphrase-2"}),
            content_type="application/json",
        )
        other = {"authorization": f"Bearer {body(r)['token']}"}
        row = [{"id": "seeded-cny", "slug": "cny", "label": "春节"}]

        self.push(row)
        self.client.post(
            "/sync",
            data=json.dumps({"tables": {"occasion_tags": row}}),
            content_type="application/json",
            headers=other,
        )
        self.assertEqual(len(self.pull()), 1)
        self.assertEqual(OccasionTag.objects.filter(client_id="seeded-cny").count(), 2)


class AccountDeletionTests(TestCase):
    """In-app account deletion (App Store 5.1.1(v), Google Play).

    ⚠ The only irreversible thing the API does, so these pin that it takes the
    RIGHT account, ALL of it, and nothing else — and that a borrowed phone with
    a live token cannot do it without the password."""

    def setUp(self):
        cache.clear()
        self.auth = self.register("leonard", "a-long-passphrase-1")
        self.other = self.register("sri", "a-long-passphrase-2")
        for who, name in ((self.auth, "Pak Andi"), (self.other, "Bu Ratna")):
            self.client.post(
                "/sync",
                data=json.dumps({"tables": {
                    "people": [{"id": f"p-{name}", "name": name}],
                    "occasion_tags": [{"id": "seeded-cny", "slug": "cny", "label": "春节"}],
                }}),
                content_type="application/json",
                headers=who,
            )

    def register(self, username, password):
        r = self.client.post(
            "/auth/register",
            data=json.dumps({"username": username, "password": password}),
            content_type="application/json",
        )
        return {"authorization": f"Bearer {body(r)['token']}"}

    def delete(self, headers, password):
        return self.client.post(
            "/auth/delete",
            data=json.dumps({"password": password}),
            content_type="application/json",
            headers=headers,
        )

    def test_it_needs_a_valid_token(self):
        self.assertEqual(self.delete({}, "a-long-passphrase-1").status_code, 401)
        self.assertTrue(User.objects.filter(username="leonard").exists())

    def test_a_token_without_the_password_deletes_nothing(self):
        # ⚠ The unlocked-phone-on-a-table case.
        r = self.delete(self.auth, "not-my-password")
        self.assertEqual(r.status_code, 403, "403, so the client does not sign out")
        self.assertTrue(User.objects.filter(username="leonard").exists())
        self.assertEqual(Person.objects.filter(owner__username="leonard").count(), 1)

    def test_the_password_check_is_rate_limited(self):
        for _ in range(10):
            self.delete(self.auth, "guess")
        self.assertEqual(self.delete(self.auth, "a-long-passphrase-1").status_code, 429)
        self.assertTrue(User.objects.filter(username="leonard").exists())

    def test_it_removes_the_account_everything_it_synced_and_every_device(self):
        second_device = self.client.post(
            "/auth/login",
            data=json.dumps({"username": "leonard", "password": "a-long-passphrase-1"}),
            content_type="application/json",
        )
        mac = {"authorization": f"Bearer {body(second_device)['token']}"}

        self.assertEqual(self.delete(self.auth, "a-long-passphrase-1").status_code, 200)

        self.assertFalse(User.objects.filter(username="leonard").exists())
        # ⚠ Absolute counts. Filtering on owner__username="leonard" after the
        # user is gone matches nothing whether or not the rows survived.
        self.assertEqual(list(Person.objects.values_list("name", flat=True)), ["Bu Ratna"])
        self.assertEqual(OccasionTag.objects.count(), 1)
        self.assertEqual(AuthToken.objects.count(), 1, "only sri's token remains")
        # The other device finds out on its next sync, as a 401.
        self.assertEqual(self.client.get("/sync", headers=mac).status_code, 401)

    def test_it_touches_no_other_account(self):
        self.delete(self.auth, "a-long-passphrase-1")
        rows = json.loads(self.client.get("/sync", headers=self.other).content)["tables"]
        self.assertEqual([p["name"] for p in rows["people"]], ["Bu Ratna"])
        # Same seeded id, different owner — must survive.
        self.assertEqual(len(rows["occasion_tags"]), 1)

    def test_the_username_can_start_again_empty(self):
        self.delete(self.auth, "a-long-passphrase-1")
        fresh = self.register("leonard", "a-new-long-passphrase")
        rows = json.loads(self.client.get("/sync", headers=fresh).content)["tables"]
        self.assertEqual(rows["people"], [])

    def test_only_post(self):
        self.assertEqual(self.client.get("/auth/delete", headers=self.auth).status_code, 405)


class SignupLimitTests(TestCase):
    """Open signup must not mean unlimited signup.

    ⚠ The failure throttle never sees a SUCCESSFUL registration, so before this
    a script could create accounts without end, each able to fill its cap."""

    def setUp(self):
        cache.clear()

    def signup(self, username, ip="10.0.0.1", password="a-long-passphrase-1"):
        return self.client.post(
            "/auth/register",
            data=json.dumps({"username": username, "password": password}),
            content_type="application/json",
            REMOTE_ADDR=ip,
        )

    @override_settings(REGISTRATION_SECRET="")
    def test_the_sixth_account_from_one_network_in_an_hour_is_refused(self):
        for i in range(5):
            self.assertEqual(self.signup(f"user{i}").status_code, 201)
        r = self.signup("user5")
        self.assertEqual(r.status_code, 429)
        self.assertIn("new accounts", body(r)["detail"])
        self.assertFalse(User.objects.filter(username="user5").exists())

    @override_settings(REGISTRATION_SECRET="")
    def test_another_network_is_unaffected(self):
        for i in range(5):
            self.signup(f"user{i}")
        self.assertEqual(self.signup("elsewhere", ip="10.0.0.2").status_code, 201)

    @override_settings(REGISTRATION_SECRET="")
    def test_a_failed_signup_does_not_use_up_the_allowance(self):
        # Someone fumbling a taken name or a weak password is not abuse.
        self.signup("taken")
        for _ in range(6):
            self.assertEqual(self.signup("taken").status_code, 409)
        for i in range(4):
            self.assertEqual(self.signup(f"ok{i}").status_code, 201)


@override_settings(REGISTRATION_SECRET="", ACCOUNT_STORAGE_LIMIT_BYTES=3000)
class StorageLimitTests(TestCase):
    """The per-account cap — here shrunk to 3000 so rows can reach it."""

    def setUp(self):
        cache.clear()
        self.auth = self.register("leonard", "10.0.0.1")
        self.other = self.register("sri", "10.0.0.2")

    def register(self, username, ip):
        r = self.client.post(
            "/auth/register",
            data=json.dumps({"username": username, "password": "a-long-passphrase-1"}),
            content_type="application/json",
            REMOTE_ADDR=ip,
        )
        return {"authorization": f"Bearer {body(r)['token']}"}

    def push(self, headers, people):
        return self.client.post(
            "/sync",
            data=json.dumps({"tables": {"people": people}}),
            content_type="application/json",
            headers=headers,
        )

    def person(self, i, notes_len=0, **extra):
        return {"id": f"p{i}", "name": f"Person {i}", "notes": "x" * notes_len, **extra}

    def test_normal_use_is_nowhere_near_it(self):
        r = self.push(self.auth, [self.person(i) for i in range(5)])
        self.assertEqual(r.status_code, 200)

    def test_a_push_that_would_cross_it_is_refused_whole(self):
        self.push(self.auth, [self.person(0, notes_len=1500)])
        r = self.push(self.auth, [self.person(1), self.person(2, notes_len=2000)])
        self.assertEqual(r.status_code, 413)
        # ⚠ All or nothing: p1 fit on its own, and must not have been written.
        self.assertEqual(
            sorted(Person.objects.filter(owner__username="leonard")
                   .values_list("client_id", flat=True)), ["p0"])

    def test_a_full_account_can_still_edit_and_delete(self):
        # ⚠ Counting every pushed row as new would lock a full account out of
        # the very edits that make room.
        self.push(self.auth, [self.person(0, notes_len=2500)])
        same_size = self.push(self.auth, [self.person(0, notes_len=2500)])
        self.assertEqual(same_size.status_code, 200)
        smaller = self.push(self.auth, [self.person(0, notes_len=10)])
        self.assertEqual(smaller.status_code, 200)
        self.push(self.auth, [self.person(0, notes_len=2500)])
        tombstone = self.push(self.auth, [{"id": "p0", "deleted_at": "2026-09-18T00:00:00Z"}])
        self.assertEqual(tombstone.status_code, 200)

    def test_one_account_filling_up_does_not_touch_another(self):
        self.push(self.auth, [self.person(0, notes_len=2500)])
        self.assertEqual(self.push(self.auth, [self.person(1, notes_len=1000)]).status_code, 413)
        self.assertEqual(self.push(self.other, [self.person(9, notes_len=1000)]).status_code, 200)


class PrivacyPolicyTests(TestCase):
    """GET /privacy — the App Store policy URL."""

    @override_settings(PRIVACY_CONTACT_EMAIL="privacy@example.com")
    def test_anyone_can_read_it_without_an_account(self):
        r = self.client.get("/privacy")
        self.assertEqual(r.status_code, 200)
        self.assertIn("text/html", r["Content-Type"])
        self.assertContains(r, "Privacy Policy")
        self.assertContains(r, 'mailto:privacy@example.com')

    @override_settings(PRIVACY_CONTACT_EMAIL="")
    def test_a_missing_contact_is_loud_not_blank(self):
        r = self.client.get("/privacy")
        self.assertEqual(r.status_code, 503)
        self.assertNotContains(r, "Privacy Policy", status_code=503)

    @override_settings(PRIVACY_CONTACT_EMAIL='"><script>alert(1)</script>')
    def test_the_contact_setting_cannot_inject_markup(self):
        self.assertNotContains(self.client.get("/privacy"), "<script>")

    def test_being_public_opens_nothing_else(self):
        self.assertEqual(self.client.get("/privacy/").status_code, 401)
        self.assertEqual(self.client.get("/privacyx").status_code, 401)
        self.assertEqual(self.client.get("/sync").status_code, 401)

    @override_settings(PRIVACY_CONTACT_EMAIL="privacy@example.com")
    def test_it_claims_nothing_the_server_does_not_do(self):
        # ⚠ Synced data is encrypted IN TRANSIT only. Until end-to-end
        # encryption exists, the policy must not suggest that it does.
        page = self.client.get("/privacy").content.decode().lower()
        for claim in ("end-to-end", "end to end", "only you can read",
                      "we can't read", "we cannot read", "zero-knowledge"):
            self.assertNotIn(claim, page)

    def test_every_synced_table_is_covered_by_the_policy(self):
        # Add a synced table and this fails until the policy has been re-read.
        from core.privacy import POLICY_COVERS
        from core.sync import TABLES
        self.assertEqual(POLICY_COVERS, set(TABLES))
