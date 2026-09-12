import 'dart:io' show Platform;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../data/database.dart';
import '../domain/money_fmt.dart';
import '../domain/occasions.dart';

/// ⚠ KEY INSIGHT: every notification in this app has a date that is known at
/// creation time. Occasions are seeded; pings are chosen by the user. NOTHING
/// needs computing on a schedule.
///   ⇒ flutter_local_notifications, on-device. No server cron, no FCM, no APNs.
/// A notification id must be an int, and it must be REPRODUCIBLE — the old id
/// has to be cancellable on the next launch or duplicates accumulate.
/// `String.hashCode` is not guaranteed stable across runs, so hash explicitly.
/// FNV-1a, folded to 28 bits, then 3 bits of slot: 8 notifications per row.
int notificationId(String uuid, int slot) {
  var h = 0x811c9dc5;
  for (final c in uuid.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return ((h & 0x0fffffff) * 8) + (slot & 0x7);
}

/// The one [Notifier], set once in `main()`.
///
/// ⚠ Deliberately module-level rather than threaded through the widget tree.
/// The only thing outside `main()` that needs it is the app-root lifecycle
/// hook, and an InheritedWidget for a single consumer is scope. `config.dart`
/// already establishes that a global constant beats a settings screen here.
Notifier? appNotifier;

/// Rebuild the schedule after a write that changed a date.
///
/// ⚠ Notifications are DERIVED from the database, so a meeting booked now has
/// no reminder until something reschedules. The lifecycle hook covers the
/// phone, where you close the app constantly; on the Mac you might not quit
/// for days, so every screen that writes a dated row calls this directly.
Future<void> appNotifierReschedule() async {
  await appNotifier?.rescheduleAll();
}

/// Bumped every time the user taps a notification while the app is already
/// running. `PhoneShell` listens and switches to Today.
///
/// ⚠ A counter, not a bool or a tab: two taps in a row must both register, and
/// a ValueNotifier only fires on a CHANGE. Setting a flag true twice is silent.
///
/// Cold launch does not come through here — the tap happened before anything
/// was listening. See [launchedFromNotification], which `main()` reads once.
final notificationTaps = ValueNotifier<int>(0);

class Notifier {
  Notifier(this.db);
  final AppDatabase db;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<int> _pass = Future.value(0);

  Future<void> init() async {
    tzdata.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));

    // ⚠ initialize() throws ArgumentError if the settings for the platform it
    // is running on are absent. All three are declared or the phone dies on
    // launch. iOS deliberately does NOT request here — see _checkReady().
    await _plugin.initialize(
      // ⚠ Without this the tap is dead: the app comes to the foreground on
      // whatever tab it was left on, which is Capture. B1 -> B2 is the loop
      // the whole app exists for and the notification is its first step.
      onDidReceiveNotificationResponse: (_) => notificationTaps.value++,
      settings: const InitializationSettings(
        macOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = await _checkReady();
  }

  /// ⚠ `_ready` must stay honest. A notifier that reports ready when it is not
  /// is this app's worst failure mode — the calendar looks armed and fires
  /// nothing, which is indistinguishable from a quiet month.
  Future<bool> _checkReady() async {
    // ⚠ SPIKE 0.1b: on macOS initialize() returns BEFORE the permission prompt
    // is answered, so its return value is meaningless. Ask the system instead.
    if (Platform.isMacOS) {
      final perms = await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return perms?.isAlertEnabled ?? false;
    }

    // iOS has a better answer available than macOS does: requestPermissions()
    // awaits the user's tap and returns what they chose, so the 0.1b race does
    // not apply. That is why the iOS init settings above request nothing.
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Android 13+ gates notifications behind a runtime permission.
      final granted = await android?.requestNotificationsPermission() ?? false;
      // ⚠ Exact alarms are a SEPARATE permission, and this app is useless
      // without them. An inexact alarm may slide by hours, and a T-14 festival
      // reminder that lands on T-13 at 3am is not the reminder that was
      // scheduled. Ask only when it is not already held — the request bounces
      // the user out to a system settings screen.
      if (await android?.canScheduleExactNotifications() == false) {
        await android?.requestExactAlarmsPermission();
      }
      return granted;
    }

    return false;
  }

  bool get ready => _ready;

  /// ⚠ SPIKE 0.1 RESULT: pending notifications survive an incremental rebuild
  /// but are WIPED by a clean rebuild — macOS treats the freshly-signed .app
  /// as a different app. So this is not a safety net, it is the primary
  /// mechanism. Wipe and re-derive everything, every launch. Idempotent.
  ///
  /// ⚠ Idempotent, but NOT reentrant: the first thing it does is cancel
  /// everything, so a second pass starting midway through the first would
  /// wipe alarms the first pass had already re-added and then never replace
  /// them. Now that the lifecycle hook can fire while the launch pass is still
  /// running, calls are queued behind each other rather than overlapping.
  Future<int> rescheduleAll() {
    final pass = _pass.then((_) => _rescheduleAll());
    // Swallow into the chain only — the caller still sees a failure.
    _pass = pass.catchError((_) => 0);
    return pass;
  }

  Future<int> _rescheduleAll() async {
    await _plugin.cancelAll();

    var n = 0;
    final people = await db.allPeople();
    final occasions = await db.upcomingOccasions(withinDays: 1200);

    for (final o in occasions) {
      final tagged =
          people.where((p) => p.occasionTags.contains(o.tag)).length;
      if (tagged == 0) continue; // nothing to prepare for

      // T-14 — the whole point. Gifts need lead time; a same-day
      // notification is useless and was the original complaint.
      n += await _at(notificationId(o.id, 1), o.date.subtract(const Duration(days: 14)),
          '${o.name} in 2 weeks', taggedLabel(tagged));
      // T-3 — second pass for anyone still unmarked.
      n += await _at(notificationId(o.id, 2), o.date.subtract(const Duration(days: 3)),
          '${o.name} in 3 days', taggedLabel(tagged));
      // T+1 — close-out. ⚠ Without this, expected rows accumulate forever and
      // the balance silently drifts from reality.
      n += await _at(notificationId(o.id, 3), o.date.add(const Duration(days: 1)),
          'Mark ${o.name} gift spend as actual?', 'Confirm what was spent');
    }

    // Meetings. ⚠ These are the only notifications NOT pinned to 09:00.
    // A 3pm coffee reminded at 9am is a reminder you have forgotten again by
    // lunch, so it fires an hour before — see [_atExactly].
    for (final m in await db.allMeetings()) {
      n += await _atExactly(
        notificationId(m.id, 4),
        m.startsAt.subtract(const Duration(hours: 1)),
        m.title,
        [
          fmtClock(m.startsAt),
          if ((m.location ?? '').isNotEmpty) m.location!,
        ].join(' · '),
      );
    }

    // Pings. The user chose this date personally, months earlier — one
    // notification, self-scheduled, not a nag stream.
    for (final p in people) {
      if (p.pingDate == null) continue;
      n += await _at(notificationId(p.id, 0), p.pingDate!,
          'Ping: ${p.name}${p.company != null ? ' (${p.company})' : ''}',
          p.pingNote ?? 'no note');
    }
    return n;
  }

  /// Fires at the exact moment given, rather than at 09:00 on that day.
  Future<int> _atExactly(
      int id, DateTime when, String title, String body) async {
    if (!_ready) return 0;
    final at = tz.TZDateTime.from(when, tz.local);
    if (at.isBefore(tz.TZDateTime.now(tz.local))) return 0; // already past
    return _schedule(id, at, title, body);
  }

  Future<int> _at(int id, DateTime when, String title, String body) async {
    if (!_ready) return 0;
    final at = tz.TZDateTime.from(
        DateTime(when.year, when.month, when.day, 9), tz.local);
    if (at.isBefore(tz.TZDateTime.now(tz.local))) return 0; // already past
    return _schedule(id, at, title, body);
  }

  Future<int> _schedule(
      int id, tz.TZDateTime at, String title, String body) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        // One channel. The app has one kind of notification — something is due
        // — and splitting it into "occasions" and "pings" would only let the
        // user mute half the app by accident.
        android: AndroidNotificationDetails(
          'due',
          'Reminders',
          channelDescription: 'Festivals and follow-up pings that are due.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    return 1;
  }

  /// Whether this launch was started by tapping a notification.
  ///
  /// ⚠ The warm-tap callback cannot cover this case — the process did not
  /// exist when the tap happened, so the plugin holds the response and hands
  /// it over on request instead. Read once, in `main()`, before the first
  /// frame decides which tab to open on.
  Future<bool> launchedFromNotification() async =>
      (await _plugin.getNotificationAppLaunchDetails())
          ?.didNotificationLaunchApp ??
      false;

  Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;
}

/// ⚠ Kept as an alias. The implementation moved to money_fmt.dart so the
/// calendar could use it without importing the notifier, and the name stays
/// here because three call sites already point at it.
String taggedLabel(int n) => taggedLabelFor(n);

/// Adds seeded occasions that are missing, without disturbing what is there.
///
/// ⚠ WHY THIS EXISTS. [seedIfEmpty] runs only on a virgin database, so adding
/// a row to kSeedOccasions reaches a new install and no existing one. The tag
/// would appear on the capture screen, people would get tagged with it, and no
/// notification would ever fire — because the calendar has no row to fire
/// from. Exactly the armed-and-dead shape this project keeps designing against.
///
/// ⚠ MATCHED ON (tag, year), NOT on the deterministic id. The id is derived
/// from name+date, so a hand-corrected date — which the v4 migration comment
/// exists specifically to protect — would stop matching and this would
/// resurrect the original alongside it as a duplicate.
///
/// ⚠ Deleted occasions stay deleted. A soft-deleted row still occupies its
/// (tag, year), so nothing here brings it back.
Future<int> backfillSeedOccasions(AppDatabase db) async {
  final rows = await db.select(db.occasions).get(); // includes soft-deleted
  final taken = {for (final o in rows) (o.tag, o.date.year)};

  var added = 0;
  for (final row in kSeedOccasions) {
    final key = (row.$3.name, row.$2.year);
    if (taken.contains(key)) continue;
    await db.into(db.occasions).insert(OccasionsCompanion.insert(
          id: Value(seededId(occasionSeedKey(row.$1, row.$2))),
          name: row.$1,
          date: row.$2,
          tag: row.$3.name,
          country: Value(row.$4),
        ));
    taken.add(key);
    added++;
  }
  return added;
}

/// Seeds the occasion calendar if it is empty. ⚠ Three years, not one.
Future<void> seedIfEmpty(AppDatabase db) async {
  final existing = await db.allOccasions();
  if (existing.isNotEmpty) return;
  for (final row in kSeedOccasions) {
    // ⚠ Deterministic id, not the default v4 — see seededId(). The phone seeds
    // the same calendar offline and the two must collapse to one row, not 38.
    await db.into(db.occasions).insert(OccasionsCompanion.insert(
          id: Value(seededId(occasionSeedKey(row.$1, row.$2))),
          name: row.$1,
          date: row.$2,
          tag: row.$3.name,
          country: Value(row.$4),
        ));
  }
}
