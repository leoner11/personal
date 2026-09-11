"""One bearer token. Deliberately minimal — but NOT optional.
An open unauthenticated API on a public IP is found by scanners within hours,
and the contact list and cashflow are in there.

⚠ This guards /sync ONLY. /admin is a browser surface and cannot send a bearer
header, so it is protected by its Django superuser password instead — and is
not mounted at all in production unless DJANGO_ENABLE_ADMIN=1. See urls.py."""
import secrets

from django.conf import settings
from django.http import JsonResponse


class BearerTokenMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path.startswith("/sync"):
            header = request.headers.get("Authorization", "")
            expected = f"Bearer {settings.SYNC_TOKEN}"
            # ⚠ compare_digest, not ==. String equality returns as soon as two
            # bytes differ, so how long the comparison takes leaks how much of
            # the prefix was right, one character at a time.
            if not secrets.compare_digest(header, expected):
                return JsonResponse({"detail": "unauthorized"}, status=401)
        return self.get_response(request)
