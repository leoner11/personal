"""One hardcoded bearer token. Deliberately minimal — but NOT optional.
An open unauthenticated API on a public IP is found by scanners within hours,
and the contact list and cashflow are in there."""
from django.conf import settings
from django.http import JsonResponse


class BearerTokenMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path.startswith("/sync"):
            header = request.headers.get("Authorization", "")
            expected = f"Bearer {settings.SYNC_TOKEN}"
            if header != expected:
                return JsonResponse({"detail": "unauthorized"}, status=401)
        return self.get_response(request)
