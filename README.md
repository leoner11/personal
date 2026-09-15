<p align="center">
  <img src="app/assets/brand/personal_logo.png" alt="Personal" width="120">
</p>

<h1 align="center">Personal</h1>

<p align="center">
  personal crm, literally<br>
  i promise u, no more AI integrations
</p>

<p align="center">
  <a href="https://github.com/leoner11/personal/releases/latest"><b>Download for macOS or Windows</b></a> ·
  <a href="#build-from-source">Build from source</a> ·
  <a href="server/README.md">Sync server</a>
</p>

---

## Why

(THIS IS AI WRITTEN BUT ITS TRUEEEE)

Most personal CRMs fail the same way: you stop opening them by week three. Personal is built
around that failure rather than around a contact database.

- **Today is a prompt feed, not a dashboard.** It shows only what needs doing now, and on most
  days that is nothing, which is how it should be.
- **Reminders come to you.** Every date the app knows about becomes a local notification at
  09:00, so you do not have to remember to open it.
- **Lead time is the point.** A festival reminder on the day is useless if a gift was needed,
  so occasions remind you two weeks out, three days out, and the day after.
- **Local-first.** Everything lives in a SQLite database on your machine. Sync is optional and
  never blocks a screen.


## Features

(THIS IS AI WRITTEN BUT ITS ALSO TRUEEEE)

| | |
|---|---|
| ☀️ **Today** | Meetings today and tomorrow, tasks due or overdue, occasions in the next 14 days, follow-up pings, and expected money to confirm. |
| ✅ **Tasks** | Type a line and press Enter. Add a due date or link a person or project when it matters. Tasks show on the calendar, and on Today when due. |
| 📅 **Calendar** | Month grid with the day's detail beneath. Meetings with time, place and links, reminded the day before and an hour before. Export a meeting to your calendar app. |
| 👥 **People** | WhatsApp or WeChat channel, occasion tags, follow-up pings, and a timeline of touches, notes, money and meetings. |
| 🎁 **Occasions** | A seeded three-year calendar of Chinese, Indonesian and Malaysian festivals. Reminders go to anyone tagged, and you are warned before the calendar runs out. |
| 📁 **Projects** | Deals, JVs, clients and leads, with a free-text status, on purpose. It is not a sales pipeline. |
| 💰 **Money** | Cashflow only: what came in, what went out, what is expected. Not bookkeeping. |
| 📝 **Notes** | Plain notes, optionally linked to a person or a project. |

## Download

Get the latest build from **[Releases](https://github.com/leoner11/personal/releases/latest)**.

### macOS

Download `Personal-<version>-macOS.zip`, unzip it, and move **Personal.app** to Applications.

The build is not notarized, so macOS blocks the first launch. Either:

- open **System Settings → Privacy & Security** and click **Open Anyway** next to Personal, or
- run `xattr -dr com.apple.quarantine /Applications/Personal.app`.

> [!IMPORTANT]
> **Allow notifications.** On first launch macOS asks for permission, or you can grant it later
> in **System Settings → Notifications → Personal**. Without it nothing is scheduled, and the
> app gives no sign of it: a missing permission looks exactly like a quiet day.

### Windows

Download `Personal-<version>-Windows.zip`, unzip it anywhere (for example into
`C:\Users\<you>\Apps`), and run **Personal\Personal.exe**. Keep the folder together: the exe needs
the files beside it.

The build is not code-signed, so SmartScreen may say *Windows protected your PC*. Click
**More info → Run anyway**.

Windows does not ask for notification permission. If reminders never appear, check
**Settings → System → Notifications** and make sure Personal and notifications in general are on.

> [!NOTE]
> The Windows build is new and has not yet been tried on a real PC. Reports of anything that
> looks wrong are very welcome.

The downloads are local-only. To sync between devices, run your own
[sync server](server/README.md) and build the app with its address (see below).

## Platforms

| Platform | Status |
|---|---|
| macOS 10.15+ | ✅ Primary client, in daily use |
| Windows 10+ | 🟡 Builds in CI; not yet run on a real PC |
| Android | 🟡 Builds and runs; tested on an emulator only |
| iOS | 🟡 Compiles; not yet run on a device |
| Linux | ❌ Not yet |

Mac and Windows share the same desktop layout. On Windows the app keeps the normal title bar,
and shortcuts use **Ctrl** where the Mac uses **⌘** (Ctrl+1 to Ctrl+8 for sections, Ctrl+N to
add a person).

The phone client is a separate shell built for one hand. Capture is its first tab, and it
shares all of its domain logic with the desktop app.

## Build from source

Requires Flutter (stable, 3.41 or later), plus Xcode for macOS or Visual Studio 2022 with
**Desktop development with C++** for Windows. Each platform has to be built on that platform.

```bash
git clone https://github.com/leoner11/personal.git
cd personal/app
flutter pub get

flutter build macos --release     # on a Mac
# → build/macos/Build/Products/Release/Personal.app

flutter build windows --release   # on Windows
# → build\windows\x64\runner\Release\Personal.exe
```

Publishing a GitHub release also runs [`.github/workflows/windows.yml`](.github/workflows/windows.yml),
which builds the Windows app and attaches `Personal-<tag>-Windows.zip` to the release. It can
be run by hand from the Actions tab too.

To sync, set `kSyncBaseUrl` in [`app/lib/domain/config.dart`](app/lib/domain/config.dart) to
your server's `https://` address before building. Plain `http://` is refused on purpose. Then
sign in from the sync line at the bottom of the sidebar.

## Sync server

A small Django + SQLite server in [`server/`](server/README.md): multi-user, one token per
device, only token hashes stored, and last-write-wins, which is safe because only one person
edits their own data. A single script sets it up on a fresh Ubuntu droplet with Caddy, TLS,
systemd and daily backups.

```bash
DOMAIN=crm.example.com bash server/deploy/bootstrap.sh
```

Details, environment variables and what is exposed: [`server/README.md`](server/README.md).

## Your data

| | |
|---|---|
| Where (macOS) | `~/Library/Containers/com.mjcxstudio.personalCrm/Data/Documents/personal_crm.sqlite` |
| Where (Windows) | `%USERPROFILE%\Documents\personal_crm.sqlite` |
| Backup | `sqlite3 <that path> ".backup 'personal-backup.sqlite'"`, or copy the file while the app is closed |
| Deletes | Soft deletes only, so another device can learn a row is gone |
| Upgrades | Schema migrations run on launch and only add. Back up before installing a new version. |

Quit the app before writing to the database by hand. It holds the file open and will not see
outside changes until it restarts.

## Development

```
app/
  lib/data/      drift schema and queries (SQLite)
  lib/domain/    shared logic: Today, agenda, tasks, notifications, sync, auth
  lib/ui/        desktop shell and screens (Mac and Windows)
  lib/ui/phone/  phone shell and screens
  test/          unit and widget tests
  windows/       Windows runner: exe name, icon, version info
server/
  core/          models, sync, auth, tests
  deploy/        bootstrap, update, Caddy, systemd
```

```bash
# app
cd app
dart run build_runner build --delete-conflicting-outputs   # after changing the schema
flutter analyze
flutter test

# server
cd server
python3 -m venv .venv && ./.venv/bin/pip install -r requirements.txt
DJANGO_DEBUG=1 ./.venv/bin/python manage.py test core
```

> [!NOTE]
> The Django tests need `DJANGO_DEBUG=1`. Without it every request is redirected to HTTPS and
> nearly every test fails in a way that looks like a broken server.
>
> The Dart code is hand-formatted. Running `dart format` over it rewrites hundreds of untouched
> lines, so format only what you change.

## License

[GNU AGPL-3.0](LICENSE).
