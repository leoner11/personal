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
from django.core.exceptions import ValidationError as FieldValidationError
from django.core.validators import validate_email
from django.contrib.auth.password_validation import (
    ValidationError,
    validate_password,
)
from django.conf import settings
from django.core.cache import cache
from django.core.mail import send_mail
from django.db import transaction
from django.http import JsonResponse
from django.utils import timezone
from django.utils.crypto import salted_hmac
from django.views.decorators.csrf import csrf_exempt

from .models import AuthToken, PasswordReset

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


def _account_id(data) -> str:
    """The account identifier: an email address, normalised.

    ⚠ LOWERCASED. Mail is case-insensitive in practice, and without this
    Leonard@ and leonard@ become two accounts that look identical in a support
    request and cannot both be reset.

    ⚠ Accepts the old "username" key as well. The Mac build already installed
    sends it, and refusing it would lock that copy out of a server it used to
    work with. New clients send "email".
    """
    raw = data.get("email")
    if raw is None:
        raw = data.get("username")
    return (raw or "").strip().lower()


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
    email = _account_id(data)
    password = data.get("password") or ""
    if not email or not password:
        return JsonResponse(
            {"detail": "email and password are required"}, status=400
        )
    try:
        validate_email(email)
    except FieldValidationError:
        return JsonResponse(
            {"detail": "that does not look like an email address"}, status=400
        )

    with transaction.atomic():
        # ⚠ Stored in BOTH fields. username is what carries the unique
        # constraint (User.email is not unique in Django), and email is what a
        # password-reset flow would read if one is ever added.
        if User.objects.filter(username=email).exists():
            return JsonResponse(
                {"detail": "that email already has an account"}, status=409
            )
        try:
            validate_password(password)
        except ValidationError as e:
            return JsonResponse({"detail": " ".join(e.messages)}, status=400)
        user = User.objects.create_user(
            username=email, email=email, password=password
        )
        token = _issue(user, data.get("device", ""))

    # Only a signup that happened counts: a taken username or a weak password
    # must not use up the allowance of someone trying to get it right.
    cache.add(_signup_key(request), 0, _SIGNUP_WINDOW_SECONDS)
    try:
        cache.incr(_signup_key(request))
    except ValueError:
        pass

    # ⚠ "username" is still sent, for the already-installed Mac build that
    # reads it. Both keys carry the same value.
    return JsonResponse(
        {"token": token, "email": user.username, "username": user.username},
        status=201,
    )


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
        username=_account_id(data), password=data.get("password") or ""
    )
    if user is None:
        _record_failure(request)
        # ⚠ One message for both an unknown email and a wrong password. Saying
        # which was wrong tells an attacker when they have found the account.
        return JsonResponse({"detail": "invalid credentials"}, status=401)

    return JsonResponse({
        "token": _issue(user, data.get("device", "")),
        "email": user.username,
        "username": user.username,
    })


# ⚠ A SIX-DIGIT CODE, typed into the app — not a link. There is no web page on
# this server for a link to open, and a code works the same on a phone whose
# mail lives on another device. Short enough to guess, so it is the limits
# below that make it safe, not the code.
_RESET_TTL_SECONDS = 15 * 60
_RESET_MAX_TRIES = 5
# One mail per account per minute: "send it again" must not become a way to
# fill someone else's inbox.
_RESET_RESEND_SECONDS = 60

# ⚠ ONE ANSWER whether or not the address has an account, for the same reason
# login gives one answer for a wrong email and a wrong password.
_RESET_SENT = "if that email has an account, a code is on its way"
_RESET_BAD_CODE = "that code is not right or has expired"


def _hash_code(user, code: str) -> str:
    """⚠ Keyed with SECRET_KEY and the account, unlike hash_token. A token is
    256 random bits; this is one of a million values, and a plain hash of it
    in a leaked backup is reversed by trying all of them."""
    return salted_hmac(
        "core.auth.reset", f"{user.pk}:{code}", algorithm="sha256"
    ).hexdigest()


@csrf_exempt
def reset_request(request):
    """POST /auth/reset/request {email} — emails a code to the account's
    address. Nothing about the account changes until the code comes back."""
    if request.method != "POST":
        return JsonResponse({"detail": "method not allowed"}, status=405)
    if not settings.PASSWORD_RESET_ENABLED:
        # ⚠ LOUD, like /privacy without a contact. A server with no mail set
        # up that answered "a code is on its way" would leave someone waiting
        # for an email that cannot come.
        return JsonResponse(
            {"detail": "password reset is not set up on this server"},
            status=503,
        )
    if _too_many(request):
        return JsonResponse({"detail": "too many attempts"}, status=429)

    data = _body(request)
    if data is None:
        return JsonResponse({"detail": "invalid json"}, status=400)
    email = _account_id(data)
    if not email:
        return JsonResponse({"detail": "email is required"}, status=400)

    # ⚠ Every request counts toward the limit, found or not: this endpoint
    # sends mail, and an unlimited one is a way to spam strangers from our
    # address.
    _record_failure(request)

    user = User.objects.filter(username=email, is_active=True).first()
    if user is None:
        return JsonResponse({"detail": _RESET_SENT})

    now = timezone.now()
    pending = PasswordReset.objects.filter(user=user).first()
    if (
        pending is not None
        and (now - pending.sent_at).total_seconds() < _RESET_RESEND_SECONDS
    ):
        return JsonResponse({"detail": _RESET_SENT})

    code = f"{secrets.randbelow(1_000_000):06d}"
    try:
        send_mail(
            "Your Personal password reset code",
            f"Your code is {code}\n\n"
            "Enter it in the app to choose a new password. It works for 15 "
            "minutes.\n\n"
            "If you did not ask for this, ignore this email: your password "
            "has not changed.\n",
            None,
            [user.email or user.username],
        )
    except Exception:
        # ⚠ Not stored: a code nobody received must not sit there live.
        return JsonResponse(
            {"detail": "the email could not be sent, try again later"},
            status=502,
        )
    PasswordReset.objects.update_or_create(
        user=user,
        defaults={"code_hash": _hash_code(user, code), "sent_at": now, "tries": 0},
    )
    return JsonResponse({"detail": _RESET_SENT})


@csrf_exempt
def reset_confirm(request):
    """POST /auth/reset/confirm {email, code, password, device} — sets the new
    password and signs this device in, answering like /auth/login.

    ⚠ EVERY OTHER DEVICE IS SIGNED OUT. Someone resets a password because they
    forgot it or because somebody else has it, and in the second case the
    tokens already issued are the problem. Their local data is untouched."""
    if request.method != "POST":
        return JsonResponse({"detail": "method not allowed"}, status=405)
    if _too_many(request):
        return JsonResponse({"detail": "too many attempts"}, status=429)

    data = _body(request)
    if data is None:
        return JsonResponse({"detail": "invalid json"}, status=400)
    code = str(data.get("code") or "").strip()
    password = data.get("password") or ""
    if not code or not password:
        return JsonResponse(
            {"detail": "code and password are required"}, status=400
        )

    user = User.objects.filter(username=_account_id(data), is_active=True).first()
    pending = (
        PasswordReset.objects.filter(user=user).first() if user else None
    )
    if pending is None:
        _record_failure(request)
        return JsonResponse({"detail": _RESET_BAD_CODE}, status=400)
    age = (timezone.now() - pending.sent_at).total_seconds()
    if age > _RESET_TTL_SECONDS or pending.tries >= _RESET_MAX_TRIES:
        pending.delete()
        _record_failure(request)
        return JsonResponse({"detail": _RESET_BAD_CODE}, status=400)
    if not secrets.compare_digest(pending.code_hash, _hash_code(user, code)):
        # ⚠ Counted on the CODE, not only on the network: the per-IP limit
        # alone lets a million guesses through from enough addresses.
        pending.tries += 1
        pending.save(update_fields=["tries"])
        _record_failure(request)
        return JsonResponse({"detail": _RESET_BAD_CODE}, status=400)

    try:
        validate_password(password, user)
    except ValidationError as e:
        # ⚠ The code survives a weak password: it was right, and making them
        # wait for a second email over a too-short password helps nobody.
        return JsonResponse({"detail": " ".join(e.messages)}, status=422)

    with transaction.atomic():
        user.set_password(password)
        user.save(update_fields=["password"])
        pending.delete()
        AuthToken.objects.filter(user=user).delete()
        token = _issue(user, data.get("device", ""))
    return JsonResponse(
        {"token": token, "email": user.username, "username": user.username}
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
    return JsonResponse(
        {"email": request.user.username, "username": request.user.username}
    )
