"""Bearer tokens, now belonging to accounts rather than to the deployment.

An unauthenticated API on a public IP is found by scanners within hours, and
the contact list and the cashflow are both behind this.

⚠ NO CSRF, DELIBERATELY. These are native clients, not a browser: there is no
cookie the OS will attach on its own, so there is no cross-site request to
forge. The token is only ever sent because the app chose to send it.
"""
import secrets

from django.http import JsonResponse
from django.utils import timezone

from .auth import hash_token
from .models import AuthToken

# Everything except these needs a valid token.
PUBLIC_PATHS = ("/auth/register", "/auth/login")


class BearerTokenMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path in PUBLIC_PATHS:
            return self.get_response(request)

        header = request.headers.get("Authorization", "")
        scheme, _, raw = header.partition(" ")
        # ⚠ compare_digest on the scheme too: "Basic <token>" must not pass
        # merely because the token part happens to be right.
        if not secrets.compare_digest(scheme, "Bearer") or not raw:
            return JsonResponse({"detail": "unauthorized"}, status=401)

        # ⚠ Look up by HASH. The raw token is never stored, so it cannot be
        # read back out of the database — and the lookup stays one indexed
        # query rather than a scan-and-compare over every token.
        token = (
            AuthToken.objects.select_related("user")
            .filter(key_hash=hash_token(raw))
            .first()
        )
        if token is None or not token.user.is_active:
            return JsonResponse({"detail": "unauthorized"}, status=401)

        token.last_used_at = timezone.now()
        token.save(update_fields=["last_used_at"])

        request.user = token.user
        request.auth_token = token
        return self.get_response(request)
