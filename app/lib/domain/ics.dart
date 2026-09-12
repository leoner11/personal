import 'dart:io';

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

/// Writes the file and opens it, which on macOS hands it to Calendar.app.
/// Returns the path, or null if it could not be opened.
Future<String?> openInCalendar(Meeting m, {String? personName}) async {
  final dir = await getApplicationDocumentsDirectory();
  // ⚠ Named by id, so exporting the same meeting twice overwrites rather than
  // filling the documents directory with near-identical files.
  final file = File('${dir.path}/meeting-${m.id}.ics');
  await file.writeAsString(icsFor(m, personName: personName));

  final uri = Uri.file(file.path);
  if (!await launchUrl(uri)) return null;
  return file.path;
}
