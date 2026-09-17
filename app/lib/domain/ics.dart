import 'dart:io';

import 'package:add_2_calendar/add_2_calendar.dart' as add2;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/database.dart';

/// One-way export to the real calendar.
///
/// ⚠ A SNAPSHOT, NOT A SYNC. Opening the file hands Calendar.app a copy of the
/// meeting as it is right now. Edit the meeting here afterwards and the copy
/// over there does not follow — it has no idea this app exists. Anything that
/// claims otherwise in the UI would be a lie.
///
/// ⚠ Live two-way access to macOS Calendar is possible, but not like this: it
/// needs EventKit through a native plugin channel, plus
/// `com.apple.security.personal-information.calendars` in both entitlements
/// files, and it is macOS/iOS only. Deliberately not built — this gets most of
/// the value for none of the native surface.
String icsFor(Meeting m, {String? personName}) {
  final start = m.startsAt;
  final end = start.add(Duration(minutes: m.durationMinutes));

  // ⚠ Local time WITHOUT a trailing Z, and no VTIMEZONE block. A meeting at
  // 15:00 means 15:00 where you are; stamping it UTC without declaring the
  // zone is how an event lands in a calendar three hours out.
  String stamp(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}T'
      '${d.hour.toString().padLeft(2, '0')}'
      '${d.minute.toString().padLeft(2, '0')}00';

  final description = [
    if (personName != null && personName.isNotEmpty) 'With $personName',
    if ((m.notes ?? '').isNotEmpty) m.notes!,
  ].join('\\n');

  // ⚠ RFC 5545 wants CRLF line endings. Calendar.app tolerates bare \n;
  // Outlook and Google do not always, and a file that silently imports
  // nowhere is worse than one that errors.
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Personal//CRM//EN',
    'BEGIN:VEVENT',
    // Stable, so re-exporting the same meeting UPDATES the calendar entry
    // rather than creating a second copy of it.
    'UID:${m.id}@personal-crm',
    'DTSTAMP:${stamp(DateTime.now())}',
    'DTSTART:${stamp(start)}',
    'DTEND:${stamp(end)}',
    'SUMMARY:${_esc(m.title)}',
    if ((m.location ?? '').isNotEmpty) 'LOCATION:${_esc(m.location!)}',
    if (description.isNotEmpty) 'DESCRIPTION:${_esc(description)}',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');
}

/// ⚠ Commas, semicolons and backslashes are field separators in iCalendar.
/// An unescaped comma in "Coffee, then the warehouse" truncates the title.
String _esc(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;')
    .replaceAll('\n', '\\n');

/// Puts the meeting in the phone's or the computer's real calendar.
///
/// ⚠ TWO ROUTES, AND THEY ARE NOT THE SAME MECHANISM — because the platforms
/// are not. Desktop writes a .ics and opens a `file://` URL, which macOS
/// routes to Calendar.app. That route is a dead end on a phone:
///
///   * `file://` means nothing to another sandboxed app on iOS/Android; and
///   * **the share sheet does not solve it either.** Handing iOS a .ics offers
///     Copy and Save to Files and nothing else — Calendar.app registers no
///     share extension, so the file goes to Files and the user is left to find
///     and tap it. Verified on the simulator; that approach was built, tried,
///     and dropped.
///
/// So mobile uses the platform's own "add an event" intent instead:
/// `EKEventEditViewController` on iOS, `Intent.ACTION_INSERT` on Android. Both
/// open the calendar's own pre-filled new-event screen and let the user
/// confirm — no silent write, and on Android no permission at all.
///
/// ⚠ STILL A SNAPSHOT, NOT A SYNC, on every platform. The event is a copy
/// taken now. Edit the meeting here afterwards and the calendar's copy does
/// not follow — it has no idea this app exists. Anything in the UI that
/// implies otherwise is a lie.
///
/// Returns a path on desktop, the empty string when a phone accepted the
/// event, or null if the platform refused it.
Future<String?> openInCalendar(Meeting m, {String? personName}) async {
  if (Platform.isIOS || Platform.isAndroid) {
    final ok = await add2.Add2Calendar.addEvent2Cal(add2.Event(
      title: m.title,
      description: [
        if ((personName ?? '').isNotEmpty) 'With $personName',
        if ((m.notes ?? '').isNotEmpty) m.notes!,
      ].join('\n'),
      location: m.location ?? '',
      startDate: m.startsAt,
      endDate: m.startsAt.add(Duration(minutes: m.durationMinutes)),
      // ⚠ NO reminder set here, deliberately — the calendar applies whatever
      // default the user already chose for it. This app's own notification
      // (a day before, then an hour before) is separate and keeps firing
      // either way; forcing an alert as well would hard-code a second one
      // nobody asked for. The edit screen is right there if they want it.
    ));
    return ok ? '' : null;
  }

  final dir = await getApplicationDocumentsDirectory();
  // ⚠ Named by id, so exporting the same meeting twice overwrites rather than
  // filling the documents directory with near-identical files.
  final file = File('${dir.path}/meeting-${m.id}.ics');
  await file.writeAsString(icsFor(m, personName: personName));

  final uri = Uri.file(file.path);
  if (!await launchUrl(uri)) return null;
  return file.path;
}
