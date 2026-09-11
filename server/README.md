# Personal CRM — sync server

Django + SQLite. Sync target only; the clients never depend on it being up.

## Local

`DJANGO_DEBUG=1` is what makes this a development server: it mounts `/admin`,
allows the placeholder token, and turns off the HTTPS redirect.

```bash
cd server
python3 -m venv .venv && ./.venv/bin/pip install django
DJANGO_DEBUG=1 ./.venv/bin/python manage.py migrate
DJANGO_DEBUG=1 ./.venv/bin/python manage.py runserver 8765
DJANGO_DEBUG=1 ./.venv/bin/python manage.py test core   # 6 auth tests
```

## Deploying

⚠ **The token is the account.** There are no users and no login on `/sync` —
one shared bearer token is the whole auth model, which is correct for one
person with two devices, and is why the token itself has to be real.

```bash
export DJANGO_SECRET_KEY=$(python3 -c 'import secrets;print(secrets.token_urlsafe(50))')
export SYNC_TOKEN=$(python3 -c 'import secrets;print(secrets.token_urlsafe(32))')
export DJANGO_ALLOWED_HOSTS=crm.example.com
# DJANGO_DEBUG unset. DJANGO_ENABLE_ADMIN unset unless you want /admin.
```

Then put the same `SYNC_TOKEN` into `app/lib/domain/config.dart` as
`kSyncToken`, set `kSyncBaseUrl` to `https://crm.example.com`, and rebuild.

| Variable | Default | Why |
|---|---|---|
| `DJANGO_SECRET_KEY` | insecure dev key | Signs sessions and CSRF. Public repo, so it cannot be committed. |
| `SYNC_TOKEN` | `dev-token-change-me` | **The server refuses to boot on the default when `DEBUG` is off.** |
| `DJANGO_ALLOWED_HOSTS` | `localhost,127.0.0.1` | Was `*`. Set it to the real host. |
| `DJANGO_DEBUG` | off | On, a 500 shows settings and locals to whoever triggered it. |
| `DJANGO_ENABLE_ADMIN` | off in production | See below. |

### What is actually exposed

- **`/sync`** — guarded by `BearerTokenMiddleware`, compared with
  `secrets.compare_digest` so the comparison time leaks nothing.
- **`/admin`** — **not** covered by that middleware; a browser cannot send an
  `Authorization` header. Its only protection is a Django superuser password,
  at a URL every scanner on the internet tries. The clients do not need it —
  the Dart `seedIfEmpty()` builds the occasion calendar on each device — so it
  is not mounted in production unless you set `DJANGO_ENABLE_ADMIN=1`.

⚠ **HTTPS is not optional.** The token rides in a header on every request, and
phone sync happens on cafe wifi. The client refuses to sync to an `http://`
URL rather than leak over it; put Caddy in front and let it do TLS.

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
