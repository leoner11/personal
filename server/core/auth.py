"""Accounts.

Ordinary signup and login. Every synced row carries an owner and every sync
query filters on it, so accounts are isolated and registration can simply be
open — a new account gets an empty app, not a view of someone else's.

⚠ That isolation is the whole reason this is safe, and it is enforced by a
(owner, client_id) uniqueness constraint in the database rather than by a check
in a view that someone can later forget. See core/models.SyncedModel.

Set REGISTRATION_SECRET to close signup on a server that only needs your own
account; leaving it unset leaves signup open.

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


# ⚠ SIGNUPS ARE COUNTED, NOT ONLY FAILURES. Signup is open to anyone, and the
# failure throttle above never fires on a successful registration — so without
# this a script could create accounts without limit, each able to fill its
# storage cap. Same in-memory, per-worker caveat as above: with two workers the
# real ceiling is up to twice this. A speed bump, and enough for a script.
_MAX_SIGNUPS = 5
_SIGNUP_WINDOW_SECONDS = 3600


def _signup_key(request) -> str:
    return f"signup:{request.META.get('REMOTE_ADDR', '?')}"


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
    """Create an account. Open unless REGISTRATION_SECRET is set."""
    if request.method != "POST":
        return JsonResponse({"detail": "method not allowed"}, status=405)

    from django.conf import settings

    # Optional gate. Unset = open signup; set = an invite code is required.
    secret = settings.REGISTRATION_SECRET
    if secret:
        presented = request.headers.get("X-Register-Secret", "")
        if not secrets.compare_digest(presented, secret):
            _record_failure(request)
            return JsonResponse(
                {"detail": "registration is closed on this server"}, status=403
            )

    if _too_many(request):
        return JsonResponse({"detail": "too many attempts"}, status=429)
    if (cache.get(_signup_key(request)) or 0) >= _MAX_SIGNUPS:
        return JsonResponse(
            {"detail": "too many new accounts from this network"}, status=429
        )

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
        if User.objects.filter(username=username).exists():
            return JsonResponse(
                {"detail": "that username is taken"}, status=409
            )
        try:
            validate_password(password)
        except ValidationError as e:
            return JsonResponse({"detail": " ".join(e.messages)}, status=400)
        user = User.objects.create_user(username=username, password=password)
        token = _issue(user, data.get("device", ""))

    # Only a signup that happened counts: a taken username or a weak password
    # must not use up the allowance of someone trying to get it right.
    cache.add(_signup_key(request), 0, _SIGNUP_WINDOW_SECONDS)
    try:
        cache.incr(_signup_key(request))
    except ValueError:
        pass

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


@csrf_exempt
def delete_account(request):
    """POST /auth/delete {password} — removes the account and everything it
    ever synced. Required by App Store guideline 5.1.1(v) and Google Play for
    any app that lets people create an account.

    ⚠ BEHIND THE TOKEN AND THE PASSWORD. The token alone is not enough: a phone
    left unlocked on a table would otherwise be one tap from erasing someone's
    whole contact list from the server. It is the only irreversible thing this
    API does, so it asks for the one thing a borrowed phone does not have.

    ⚠ A WRONG PASSWORD IS 403, NOT 401. Clients read 401 as "this device's
    token was revoked" and sign themselves out; a typo here must not do that.

    ⚠ Rate-limited with login. A token plus an unlimited password check is a
    password oracle for anyone holding a stolen token.

    Deleting the user cascades: every synced row (SyncedModel.owner) and every
    device token (AuthToken.user) go with it, so the account's other devices
    get 401 on their next sync and drop to signed-out on their own. Their local
    data is untouched — it lives on those devices, not here."""
    if request.method != "POST":
        return JsonResponse({"detail": "method not allowed"}, status=405)
    if _too_many(request):
        return JsonResponse({"detail": "too many attempts"}, status=429)

    data = _body(request)
    if data is None:
        return JsonResponse({"detail": "invalid json"}, status=400)

    user = authenticate(
        username=request.user.username, password=data.get("password") or ""
    )
    if user is None or user.pk != request.user.pk:
        _record_failure(request)
        return JsonResponse({"detail": "password is not right"}, status=403)

    with transaction.atomic():
        user.delete()
    return JsonResponse({"detail": "account deleted"})


def me(request):
    """Lets a client find out whether its stored token is still good without
    running a whole sync."""
    return JsonResponse({"username": request.user.username})
