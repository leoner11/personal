"""Two endpoints. Single user, two devices. All the horror of sync is
concurrent edits by DIFFERENT PEOPLE — that does not apply here, so
last-write-wins is genuinely correct and the whole thing is ~150 lines."""
from django.db import transaction
from django.http import JsonResponse
from django.utils.dateparse import parse_datetime
from django.views.decorators.csrf import csrf_exempt
import json

from .models import Person, Occasion, Engagement, Money, Note, Touch

TABLES = {
    "people": Person,
    "occasions": Occasion,
    "engagements": Engagement,
    "money": Money,
    "notes": Note,
    "touches": Touch,
}

# Fields the client owns. updated_at is deliberately absent — the server stamps it.
FIELDS = {
    "people": ["name", "company", "wa_number", "wechat_id", "preferred_channel",
               "met_where", "met_when", "notes", "occasion_tags", "ping_date",
               "ping_note", "deleted_at"],
    "occasions": ["name", "date", "tag", "country", "deleted_at"],
    "engagements": ["name", "type", "counterparty_id", "status", "value_minor",
                    "currency", "notes", "deleted_at"],
    "money": ["date", "direction", "amount_minor", "currency", "label", "status",
              "engagement_id", "person_id", "occasion_tag", "deleted_at"],
    "notes": ["date", "text", "person_id", "engagement_id", "tag", "deleted_at"],
    "touches": ["person_id", "date", "one_line", "deleted_at"],
}

DATETIME_FIELDS = {"met_when", "ping_date", "date", "deleted_at"}


def _serialize(obj, table):
    out = {"id": obj.id, "updated_at": obj.updated_at.isoformat()}
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
        qs = model.objects.all()
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

    with transaction.atomic():
        for table, rows in (payload.get("tables") or {}).items():
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

                pk = row.get("id")
                if pk:
                    obj, _ = model.objects.update_or_create(id=pk, defaults=data)
                else:
                    obj = model.objects.create(**data)
                stamped[table].append(_serialize(obj, table))

    return JsonResponse({"tables": stamped})


@csrf_exempt
def sync(request):
    return push(request) if request.method == "POST" else pull(request)
