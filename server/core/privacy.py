"""GET /privacy — the privacy policy, served by the server that holds the data.

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

# ⚠ Every table the server syncs, as the policy's "What you sync" list names
# them. A test compares this with core/sync.TABLES: add a synced table and it
# fails until someone has re-read the policy and updated both.
POLICY_COVERS = {
    "people", "occasions", "occasion_tags", "engagements", "money", "notes",
    "touches", "meetings", "tasks",
}


def privacy(request):
    if request.method not in ("GET", "HEAD"):
        return JsonResponse({"detail": "method not allowed"}, status=405)

    email = (settings.PRIVACY_CONTACT_EMAIL or "").strip()
    if not email:
        # ⚠ LOUD, not a policy with a blank contact line. Apple and privacy law
        # both expect a way to reach you; a page quietly missing it passes a
        # glance and fails a review. The deploy check curls this URL.
        return HttpResponse(
            "Privacy policy not configured: set PRIVACY_CONTACT_EMAIL in "
            "/etc/personal-crm.env and restart.",
            status=503,
            content_type="text/plain; charset=utf-8",
        )
    return HttpResponse(
        _POLICY.replace("{{CONTACT_EMAIL}}", escape(email)),
        content_type="text/html; charset=utf-8",
    )
