import 'package:drift/drift.dart' show Value;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../data/database.dart';
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

class Notifier {
  Notifier(this.db);
  final AppDatabase db;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        macOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
    // ⚠ SPIKE 0.1b: initialize() returns BEFORE the permission prompt is
    // answered, so its return value is meaningless. Ask the system instead.
    final perms = await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.checkPermissions();
    _ready = perms?.isAlertEnabled ?? false;
  }

  bool get ready => _ready;

  /// ⚠ SPIKE 0.1 RESULT: pending notifications survive an incremental rebuild
  /// but are WIPED by a clean rebuild — macOS treats the freshly-signed .app
  /// as a different app. So this is not a safety net, it is the primary
  /// mechanism. Wipe and re-derive everything, every launch. Idempotent.
  Future<int> rescheduleAll() async {
    await _plugin.cancelAll();

    var n = 0;
    final people = await db.watchPeople().first;
    final occasions = await db.upcomingOccasions(withinDays: 1200);

    for (final o in occasions) {
      final tagged =
          people.where((p) => p.occasionTags.contains(o.tag)).length;
      if (tagged == 0) continue; // nothing to prepare for

      // T-14 — the whole point. Gifts need lead time; a same-day
      // notification is useless and was the original complaint.
      n += await _at(notificationId(o.id, 1), o.date.subtract(const Duration(days: 14)),
          '${o.name} in 2 weeks', '$tagged people tagged');
      // T-3 — second pass for anyone still unmarked.
      n += await _at(notificationId(o.id, 2), o.date.subtract(const Duration(days: 3)),
          '${o.name} in 3 days', '$tagged people tagged');
      // T+1 — close-out. ⚠ Without this, expected rows accumulate forever and
      // the balance silently drifts from reality.
      n += await _at(notificationId(o.id, 3), o.date.add(const Duration(days: 1)),
          'Mark ${o.name} gift spend as actual?', 'Confirm what was spent');
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

  Future<int> _at(int id, DateTime when, String title, String body) async {
    if (!_ready) return 0;
    final at = tz.TZDateTime.from(
        DateTime(when.year, when.month, when.day, 9), tz.local);
    if (at.isBefore(tz.TZDateTime.now(tz.local))) return 0; // already past
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    return 1;
  }

  Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;
}

/// Seeds the occasion calendar if it is empty. ⚠ Three years, not one.
Future<void> seedIfEmpty(AppDatabase db) async {
  final existing = await db.watchOccasions().first;
  if (existing.isNotEmpty) return;
  for (final row in kSeedOccasions) {
    await db.into(db.occasions).insert(OccasionsCompanion.insert(
          name: row.$1,
          date: row.$2,
          tag: row.$3.name,
          country: Value(row.$4),
        ));
  }
}
