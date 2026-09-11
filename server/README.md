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

## Accounts

Ordinary signup and login, multi-user, with a token per device.

| Route | Auth | Notes |
|---|---|---|
| `POST /auth/register` | none, or an invite code | Open unless `REGISTRATION_SECRET` is set |
| `POST /auth/login` | none | Throttled; returns a token |
| `POST /auth/logout` | Bearer | Revokes **only** the token presented |
| `GET /auth/me` | Bearer | Cheap "is my token still good?" |
| `GET/POST /sync` | Bearer | Unchanged |

### How accounts are kept apart

Every synced row carries an `owner`, and every sync query filters on it, so a
new account gets an empty app rather than a view of yours.

⚠ **The clients generate their own primary keys**, which means a row id is a
guessable claim, not a secret — and seeded occasion ids are *deliberately
identical* on every device (UUID v5 of name + date) and therefore across
accounts too. Two consequences, both handled in the schema rather than in a
view someone can later forget:

- Uniqueness is `(owner, client_id)`, not `id`. A globally unique id would make
  the second account's entire festival calendar collide with the first's and
  vanish.
- The push path matches on `(owner, client_id)`. With the owner only in the
  payload, pushing another account's id would find *their* row and overwrite it.

Both are covered by `TenantIsolationTests`, and both were mutation-checked —
removing either guard makes those tests fail.

⚠ Signup being open is safe *because* of the above, not instead of it. Set
`REGISTRATION_SECRET` anyway on a server that only needs your own account:
an open endpoint on a public IP will be found and used to create junk accounts
even though they see nothing of yours.

⚠ **Native clients, so no cookies and no CSRF.** A phone has no ambient
credential a hostile page could make it send. The server returns an opaque
token, the app keeps it in the Keychain / Android Keystore, and sends it as
`Authorization: Bearer …`. Only the SHA-256 of each token is stored, so a
database or backup leak hands over nothing usable.

### Making your account

In the app: **Review → Account** on the phone, or click the sync line in the
Mac sidebar → *Create an account*. Leave the invite code blank unless you set
`REGISTRATION_SECRET`. Every later device uses **Sign in**.

## Deploying to a $4 droplet

Ubuntu, 512MB / 1 vCPU / 10GB. That is enough for one person and SQLite, with
two caveats the scripts handle:

- ⚠ **Swap is not optional.** 512MB with no swap OOM-kills pip part way through
  installing Django and leaves a venv that looks complete and is not.
  `bootstrap.sh` adds 1GB.
- ⚠ **Two gunicorn workers, not `(2*cores)+1`.** One SQLite file and one user:
  more workers buy nothing, multiply write-lock contention, and cost ~60MB each.

Point the domain's A record at the droplet **first** — Caddy asks Let's Encrypt
for a certificate on first start and issuance fails if the name does not
already resolve there.

```bash
ssh root@<droplet-ip>
git clone https://github.com/leoner11/personal.git /srv/personal-crm
DOMAIN=crm.example.com bash /srv/personal-crm/server/deploy/bootstrap.sh
```

That installs Caddy, gunicorn behind a unix socket, a `crm` system user, ufw
(22/80/443 only), a systemd unit, generated secrets in `/etc/personal-crm.env`,
and a daily `sqlite3 .backup` keeping 14 days. It is safe to re-run.

Redeploy after pushing: `bash /srv/personal-crm/server/deploy/update.sh` —
it backs the database up *before* migrating, then restarts.

| File | What it is |
|---|---|
| `deploy/bootstrap.sh` | One-shot droplet setup |
| `deploy/update.sh` | Pull, migrate, restart |
| `deploy/Caddyfile` | TLS and the proxy header Django needs |
| `deploy/personal-crm.service` | systemd unit, hardened |

⚠ The database lives at `/srv/personal-crm/data/db.sqlite3`, **outside the git
checkout** — inside it, one `git clean` or a redeploy-by-reclone deletes it.

### Environment

```bash
export DJANGO_SECRET_KEY=$(python3 -c 'import secrets;print(secrets.token_urlsafe(50))')
export DJANGO_ALLOWED_HOSTS=crm.example.com
# DJANGO_DEBUG unset.
```

Then set `kSyncBaseUrl` in `app/lib/domain/config.dart` to
`https://crm.example.com` and rebuild. There is **no token to copy in any
more** — it comes from signing in.

| Variable | Default | Why |
|---|---|---|
| `DJANGO_SECRET_KEY` | insecure dev key | Signs sessions and CSRF. Public repo, so it cannot be committed. |
| `REGISTRATION_SECRET` | unset = signup open | Set it to require an invite code. Recommended on a personal server. |
| `DJANGO_ALLOWED_HOSTS` | `localhost,127.0.0.1` | Was `*`. Set it to the real host. |
| `DJANGO_DEBUG` | off | On, a 500 shows settings and locals to whoever triggered it. |

### What is actually exposed

- **`/sync`** — guarded by `BearerTokenMiddleware`, compared with
  `secrets.compare_digest` so the comparison time leaks nothing.
- **`/admin`** — **removed entirely**, not hidden. `django.contrib.admin` is
  not installed and nothing routes to it. It was a browser surface a bearer
  token cannot guard, at a URL every scanner tries, and the clients never
  needed it: the Dart `seedIfEmpty()` builds the occasion calendar on each
  device. The session, CSRF, auth and messages middleware went with it — with
  no browser there is no cookie for them to defend.

⚠ **HTTPS is not optional.** The token rides in a header on every request, and
phone sync happens on cafe wifi. The client refuses to sync to an `http://`
URL rather than leak over it; put Caddy in front and let it do TLS.

## Endpoints

```
GET  /sync?since=<iso8601>   -> every row changed since then, all tables
POST /sync                   -> a batch of local changes, returns stamped rows
Authorization: Bearer <token from /auth/login>
```

⚠ **The server stamps `updated_at`. Clients never set it.** Verified: a client
push carrying `updated_at: 2000-01-01` comes back stamped with server time.
One clock in the system, so last-write-wins cannot pick the wrong winner
because two devices disagree about the time.

⚠ **Soft deletes only.** Nothing ever issues a `DELETE`.

## Operating it

⚠ Do not SSH in and hand-edit rows. Two devices out of sync is debuggable;
three, where one was edited behind the app's back, is not.

The backups in `/srv/personal-crm/data/backups/` are on the same droplet, which
is a backup of the application and not of the machine. ⚠ Pull one off the box
periodically — one `scp` — or a destroyed droplet takes them with it:

```bash
scp root@<droplet>:/srv/personal-crm/data/backups/db-$(date +%F).sqlite3 ~/Backups/
```

Useful:

```bash
systemctl status personal-crm
journalctl -u personal-crm -n 50 --no-pager
journalctl -u caddy -n 50 --no-pager       # TLS issuance problems show here
```
