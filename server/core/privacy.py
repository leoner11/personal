"""GET /privacy, /terms, /support — the public pages, served by the server that
holds the data.

⚠ WHY HERE and not a separate site: the App Store needs a policy URL that works
during review, and this server must be up for sync to work anyway. One thing to
keep alive, not two; update.sh ships changes with everything else.

⚠ The contact address comes from the environment, not the file. The repository
is public, and a published inbox is a spam target."""
from pathlib import Path

from django.conf import settings
from django.http import HttpResponse, JsonResponse
from django.utils.html import escape

_POLICY = (Path(__file__).parent / "privacy.html").read_text(encoding="utf-8")
_TERMS = (Path(__file__).parent / "terms.html").read_text(encoding="utf-8")
_SUPPORT = (Path(__file__).parent / "support.html").read_text(encoding="utf-8")

# ⚠ Every table the server syncs, as the policy's "What you sync" list names
# them. A test compares this with core/sync.TABLES: add a synced table and it
# fails until someone has re-read the policy and updated both.
POLICY_COVERS = {
    "people", "occasions", "occasion_tags", "engagements", "money", "notes",
    "touches", "meetings", "tasks",
}


def _page(request, html: str, email: str, name: str, setting: str):
    if request.method not in ("GET", "HEAD"):
        return JsonResponse({"detail": "method not allowed"}, status=405)

    email = (email or "").strip()
    if not email:
        # ⚠ LOUD, not a page with a blank contact line. Apple and privacy law
        # both expect a way to reach you; a page quietly missing it passes a
        # glance and fails a review. The deploy check curls these URLs.
        return HttpResponse(
            f"{name} not configured: set {setting} in "
            "/etc/personal-crm.env and restart.",
            status=503,
            content_type="text/plain; charset=utf-8",
        )
    return HttpResponse(
        html.replace("{{CONTACT_EMAIL}}", escape(email)),
        content_type="text/html; charset=utf-8",
    )


def privacy(request):
    return _page(request, _POLICY, settings.PRIVACY_CONTACT_EMAIL,
                 "Privacy policy", "PRIVACY_CONTACT_EMAIL")


def terms(request):
    """GET /terms — the terms for the app and the hosted sync service."""
    return _page(request, _TERMS, settings.SUPPORT_CONTACT_EMAIL,
                 "Terms of service", "SUPPORT_CONTACT_EMAIL")


def support(request):
    """GET /support — the App Store support URL."""
    return _page(request, _SUPPORT, settings.SUPPORT_CONTACT_EMAIL,
                 "Support page", "SUPPORT_CONTACT_EMAIL")
