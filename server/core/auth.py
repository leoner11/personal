"""Accounts, for a single-user self-hosted server.

⚠ WHY THIS IS NOT THE USUAL LOGIN. The models carry no owner column — every
row belongs to the deployment. A second account would not get its own data, it
would get the first account's. So registration is closed by construction:
it needs a deploy-time secret AND that no account exists yet. See
settings.REGISTRATION_SECRET.

⚠ NATIVE CLIENTS, NOT A WEB APP. There is no session cookie and no CSRF here,
because there is no browser: a phone has no ambient credential to be tricked
into sending. Login returns an opaque token; the client keeps it in Keychain or
the Android Keystore and presents it as `Authorization: Bearer <token>`. That
is the same header /sync always took, so the sync path is unchanged — only
where the token comes from is new.
"""
import hashlib
import json
import secrets

from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import (
    ValidationError,
    validate_password,
)
from django.core.cache import cache
from django.db import transaction
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

from .models import AuthToken

# ⚠ A public login endpoint with no limit is a free password oracle. This is
# per-process and in local memory, so it is a speed bump rather than a wall —
# with one worker that is the whole surface, and behind several it still costs
# an attacker most of their rate. Put fail2ban on the Caddy log if you want
# more; do not mistake this for that.
_MAX_ATTEMPTS = 10
_WINDOW_SECONDS = 300


def _too_many(request) -> bool:
    ip = request.META.get("REMOTE_ADDR", "?")
    key = f"authfail:{ip}"
    return (cache.get(key) or 0) >= _MAX_ATTEMPTS


def _record_failure(request) -> None:
    ip = request.META.get("REMOTE_ADDR", "?")
    key = f"authfail:{ip}"
    # add() only sets when absent, which is what starts the window ticking.
    cache.add(key, 0, _WINDOW_SECONDS)
    try:
        cache.incr(key)
    except ValueError:
        # The window expired between the add and the incr. Nothing to count.
        pass


def _body(request):
    try:
        return json.loads(request.body or b"{}")
    except (ValueError, UnicodeDecodeError):
        return None


def hash_token(raw: str) -> str:
    """⚠ Only the hash is stored, so a database or backup leak does not hand
    over working credentials. sha256 without a salt on purpose: the input is
    256 bits of CSPRNG output, so there is nothing to brute-force and the
    lookup has to stay a single indexed query."""
    return hashlib.sha256(raw.encode()).hexdigest()


def _issue(user, label: str) -> str:
    raw = secrets.token_urlsafe(32)
    AuthToken.objects.create(
        user=user, key_hash=hash_token(raw), label=label[:64]
    )
    return raw


@csrf_exempt
def register(request):
    """Claim the deployment. Works exactly once, and only with the secret."""
    if request.method != "POST":
        return JsonResponse({"detail": "method not allowed"}, status=405)

    from django.conf import settings

    secret = settings.REGISTRATION_SECRET
    # Unset means registration is off, which is the right state for every
    # moment after the one account exists.
    if not secret:
        return JsonResponse({"detail": "registration is closed"}, status=403)

    presented = request.headers.get("X-Register-Secret", "")
    if not secrets.compare_digest(presented, secret):
        _record_failure(request)
        return JsonResponse({"detail": "registration is closed"}, status=403)

    data = _body(request)
    if data is None:
        return JsonResponse({"detail": "invalid json"}, status=400)
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""
    if not username or not password:
        return JsonResponse(
            {"detail": "username and password are required"}, status=400
        )

    with transaction.atomic():
        # ⚠ The count check and the create must not race, or two accounts end
        # up sharing one set of unowned rows.
        if User.objects.select_for_update().exists():
            return JsonResponse(
                {"detail": "an account already exists on this server"},
                status=409,
            )
        try:
            validate_password(password)
        except ValidationError as e:
            return JsonResponse({"detail": " ".join(e.messages)}, status=400)
        user = User.objects.create_user(username=username, password=password)
        token = _issue(user, data.get("device", ""))

    return JsonResponse({"token": token, "username": user.username}, status=201)


@csrf_exempt
def login(request):
    if request.method != "POST":
        return JsonResponse({"detail": "method not allowed"}, status=405)
    if _too_many(request):
        return JsonResponse({"detail": "too many attempts"}, status=429)

    data = _body(request)
    if data is None:
        return JsonResponse({"detail": "invalid json"}, status=400)

    user = authenticate(
        username=(data.get("username") or "").strip(),
        password=data.get("password") or "",
    )
    if user is None:
        _record_failure(request)
        # ⚠ One message for both a wrong username and a wrong password. Saying
        # which was wrong tells an attacker when they have found the account.
        return JsonResponse({"detail": "invalid credentials"}, status=401)

    return JsonResponse(
        {"token": _issue(user, data.get("device", "")), "username": user.username}
    )


@csrf_exempt
def logout(request):
    """Revokes the presented token only, so signing out on the phone does not
    sign out the Mac."""
    if request.method != "POST":
        return JsonResponse({"detail": "method not allowed"}, status=405)
    token = getattr(request, "auth_token", None)
    if token is not None:
        token.delete()
    return JsonResponse({"detail": "signed out"})


def me(request):
    """Lets a client find out whether its stored token is still good without
    running a whole sync."""
    return JsonResponse({"username": request.user.username})
