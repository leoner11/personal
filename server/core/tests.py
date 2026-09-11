"""⚠ These guard the two things that, if wrong, publish the contact list and
the cashflow to anyone who finds the host — and that would look completely
normal while doing it. Sync would sync. Nothing would error."""
import secrets

from django.test import SimpleTestCase, TestCase, override_settings


@override_settings(SYNC_TOKEN="the-real-token", ALLOWED_HOSTS=["testserver"])
class BearerTokenTests(TestCase):
    # TestCase, not SimpleTestCase: the accepted request reaches the sync view,
    # which queries every table.
    def test_sync_rejects_a_missing_token(self):
        self.assertEqual(self.client.get("/sync").status_code, 401)

    def test_sync_rejects_the_wrong_token(self):
        r = self.client.get("/sync", headers={"authorization": "Bearer nope"})
        self.assertEqual(r.status_code, 401)

    def test_sync_rejects_a_correct_token_with_the_wrong_scheme(self):
        # "Basic <token>" must not pass just because the token matches.
        r = self.client.get("/sync", headers={"authorization": "Basic the-real-token"})
        self.assertEqual(r.status_code, 401)

    def test_sync_rejects_a_prefix_of_the_token(self):
        r = self.client.get("/sync", headers={"authorization": "Bearer the-real"})
        self.assertEqual(r.status_code, 401)

    def test_sync_accepts_the_real_token(self):
        r = self.client.get("/sync", headers={"authorization": "Bearer the-real-token"})
        self.assertNotEqual(r.status_code, 401)


class DefaultTokenTests(SimpleTestCase):
    def test_the_published_default_is_a_known_string(self):
        # It lives in a public repository, so treat it as compromised: the
        # settings module refuses to boot on it whenever DEBUG is off.
        from crm import settings

        self.assertEqual(settings._DEV_TOKEN, "dev-token-change-me")
        self.assertFalse(
            secrets.compare_digest(settings._DEV_TOKEN, secrets.token_urlsafe(32))
        )
