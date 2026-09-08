# Personal CRM — sync server

Django + SQLite. Sync target only; the clients never depend on it being up.

## Local

```bash
cd server
python3 -m venv .venv && ./.venv/bin/pip install django
SYNC_TOKEN=test-token ./.venv/bin/python manage.py migrate
SYNC_TOKEN=test-token ./.venv/bin/python manage.py runserver 8765
```

## Endpoints

```
GET  /sync?since=<iso8601>   -> every row changed since then, all tables
POST /sync                   -> a batch of local changes, returns stamped rows
Authorization: Bearer <SYNC_TOKEN>
```

⚠ **The server stamps `updated_at`. Clients never set it.** Verified: a client
push carrying `updated_at: 2000-01-01` comes back stamped with server time.
One clock in the system, so last-write-wins cannot pick the wrong winner
because two devices disagree about the time.

⚠ **Soft deletes only.** Nothing ever issues a `DELETE`.

## Deploy (not done yet)

1. VPS, Caddy in front for automatic TLS.
2. `SYNC_TOKEN` in the environment — **change it from the default.**
3. Nightly copy of `db.sqlite3` to somewhere off the box.
4. Point `app/lib/domain/config.dart` at the host, rebuild the Mac app.

⚠ Do not SSH in and hand-edit rows. Two devices out of sync is debuggable;
three, where one was edited behind the app's back, is not.
