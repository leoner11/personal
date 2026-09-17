"""Two endpoints. Single user, two devices. All the horror of sync is
concurrent edits by DIFFERENT PEOPLE — that does not apply here, so
last-write-wins is genuinely correct and the whole thing is ~150 lines."""
from django.conf import settings
from django.db import transaction
from django.db.models import Count, Sum
from django.db.models.functions import Length
from django.http import JsonResponse
from django.utils.dateparse import parse_datetime
from django.views.decorators.csrf import csrf_exempt
import json

from .models import (Person, Occasion, OccasionTag, Engagement, Money, Note,
                     Touch, Meeting, Task)

TABLES = {
    "people": Person,
    "occasions": Occasion,
    "occasion_tags": OccasionTag,
    "engagements": Engagement,
    "money": Money,
    "notes": Note,
    "touches": Touch,
    "meetings": Meeting,
    "tasks": Task,
}

# Fields the client owns. updated_at is deliberately absent — the server stamps it.
FIELDS = {
    "people": ["name", "company", "wa_number", "wechat_id", "preferred_channel",
               "met_where", "met_when", "notes", "occasion_tags", "ping_date",
               "ping_note", "deleted_at"],
    "occasions": ["name", "date", "tag", "country", "greeting",
                  "deleted_at"],
    "occasion_tags": ["slug", "label", "hint", "greeting", "sort_order",
                      "built_in", "deleted_at"],
    "engagements": ["name", "type", "counterparty_id", "status", "value_minor",
                    "currency", "notes", "deleted_at"],
    "money": ["date", "direction", "amount_minor", "currency", "label", "status",
              "engagement_id", "person_id", "occasion_tag", "deleted_at"],
    "notes": ["date", "text", "person_id", "engagement_id", "tag", "deleted_at"],
    "touches": ["person_id", "date", "one_line", "deleted_at"],
    "meetings": ["person_id", "engagement_id", "title", "starts_at",
                 "duration_minutes", "location", "notes", "deleted_at"],
    "tasks": ["title", "notes", "created_at", "due_date", "done_at", "person_id",
              "engagement_id", "deleted_at"],
}

DATETIME_FIELDS = {"met_when", "ping_date", "date", "starts_at", "due_date",
                   "done_at", "created_at", "deleted_at"}


# A fixed allowance per row for what is not text — ids, dates, numbers, and the
# row itself. Generous on purpose: undercounting is what would let an account
# grow past the cap in rows that are nearly empty.
ROW_OVERHEAD = 200


def _text_fields(table):
    model = TABLES[table]
    return ["client_id"] + [
        f for f in FIELDS[table]
        if model._meta.get_field(f).get_internal_type() in ("CharField", "TextField")
    ]


def account_size(user):
    """What an account stores, in the units the cap is set in."""
    total = 0
    for table, model in TABLES.items():
        fields = _text_fields(table)
        agg = model.objects.filter(owner=user).aggregate(
            n=Count("pk"), **{f"len_{f}": Sum(Length(f)) for f in fields}
        )
        total += agg.pop("n") * ROW_OVERHEAD + sum(v or 0 for v in agg.values())
    return total


def _row_size(table, values):
    return ROW_OVERHEAD + sum(len(str(values.get(f) or "")) for f in _text_fields(table))


def _growth(user, tables):
    """How much a push would ADD, net of the rows it replaces.

    ⚠ Net, not gross. Editing or deleting a row at the cap must still work —
    counting every pushed row as new would lock a full account out of the very
    edits that shrink it. A field the push leaves out keeps its stored value
    (update_or_create only writes what arrives), so it keeps its stored size."""
    growth = 0
    for table, rows in tables.items():
        if table not in TABLES:
            continue
        fields = _text_fields(table)
        ids = [r.get("id") for r in rows if isinstance(r, dict) and r.get("id")]
        stored = {
            o["client_id"]: o
            for o in TABLES[table].objects.filter(owner=user, client_id__in=ids)
            .values(*fields)
        }
        for row in rows:
            if not isinstance(row, dict) or not row.get("id"):
                continue
            old = stored.get(row["id"])
            merged = {f: (row["id"] if f == "client_id" else row[f] if f in row
                          else (old or {}).get(f)) for f in fields}
            growth += _row_size(table, merged) - (_row_size(table, old) if old else 0)
    return growth


def _serialize(obj, table):
    # ⚠ client_id goes out as "id". The clients have always spoken "id" and the
    # rename is a server-side storage detail — see SyncedModel.client_id.
    out = {"id": obj.client_id, "updated_at": obj.updated_at.isoformat()}
    for f in FIELDS[table]:
        v = getattr(obj, f)
        out[f] = v.isoformat() if hasattr(v, "isoformat") else v
    return out


def pull(request):
    """GET /sync?since=<iso> -> every row changed since then, all tables."""
    since = request.GET.get("since")
    out, server_time = {}, None
    from django.utils import timezone
    server_time = timezone.now().isoformat()

    for table, model in TABLES.items():
        # ⚠ Scoped to the caller. A row with no owner is returned to nobody,
        # which is the fail-closed direction if one is ever created by a bug.
        qs = model.objects.filter(owner=request.user)
        if since:
            dt = parse_datetime(since)
            if dt:
                qs = qs.filter(updated_at__gt=dt)
        out[table] = [_serialize(o, table) for o in qs]
    return JsonResponse({"server_time": server_time, "tables": out})


@csrf_exempt
def push(request):
    """POST /sync -> a batch of local changes. Returns the stamped rows so the
    client can adopt the server's timestamps rather than its own clock."""
    payload = json.loads(request.body or "{}")
    stamped = {}

    # ⚠ Checked BEFORE writing anything, and all-or-nothing. A batch that would
    # cross the cap is refused whole: half-applying it would leave the other
    # device holding rows that reference rows the server never took.
    limit = settings.ACCOUNT_STORAGE_LIMIT_BYTES
    tables = payload.get("tables") or {}
    if limit:
        growth = _growth(request.user, tables)
        if growth > 0 and account_size(request.user) + growth > limit:
            return JsonResponse(
                {"detail": "storage limit reached", "limit_bytes": limit},
                status=413,
            )

    with transaction.atomic():
        for table, rows in tables.items():
            model = TABLES.get(table)
            if not model:
                continue
            stamped[table] = []
            for row in rows:
                data = {}
                for f in FIELDS[table]:
                    if f not in row:
                        continue
                    v = row[f]
                    if f in DATETIME_FIELDS and isinstance(v, str):
                        v = parse_datetime(v)
                    data[f] = v

                cid = row.get("id")
                if not cid:
                    # ⚠ The server never mints ids. A row without one is a
                    # client bug; skipping is safer than inventing an id that
                    # the client will never recognise as its own.
                    continue

                # ⚠ OWNER IS PART OF THE LOOKUP, not just of the payload. With
                # it only in defaults, pushing another account's id would find
                # their row and overwrite it — the clients generate their own
                # primary keys, so an id is a guessable claim, not a secret.
                # Matching on (owner, client_id) makes one account's rows
                # unreachable from another's by construction.
                obj, _ = model.objects.update_or_create(
                    owner=request.user, client_id=cid, defaults=data
                )
                stamped[table].append(_serialize(obj, table))

    return JsonResponse({"tables": stamped})


@csrf_exempt
def sync(request):
    return push(request) if request.method == "POST" else pull(request)
