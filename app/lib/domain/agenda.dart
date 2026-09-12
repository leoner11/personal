import '../data/database.dart';
import 'money_fmt.dart';

/// One dated thing on the calendar, whatever table it came from.
///
/// ⚠ Shared domain logic, not layout — the phone must not drift from the Mac
/// about what a day contains, the same reason `today.dart` exists.
class AgendaEntry {
  const AgendaEntry({
    required this.at,
    required this.kind,
    required this.title,
    this.subtitle,
    this.personId,
    this.meeting,
    this.hasTime = false,
  });

  final DateTime at;

  /// meeting | occasion | ping | touch | money
  final String kind;
  final String title;
  final String? subtitle;
  final String? personId;

  /// Present only for meetings, so the UI can open or edit the real row.
  final Meeting? meeting;

  /// ⚠ Meetings are the only kind with a clock. Everything else is a whole
  /// day, and rendering "09:00" against a festival would invent precision the
  /// data does not have.
  final bool hasTime;

  DateTime get day => DateTime(at.year, at.month, at.day);
}

/// Everything dated, in one list.
///
/// ⚠ Touches are the PAST half. They are included because the calendar is also
/// where you look back — "when did I last see Pak Arnold" is the same question
/// as "when am I seeing him next", asked in the other direction.
Future<List<AgendaEntry>> loadAgenda(
  AppDatabase db, {
  required DateTime from,
  required DateTime to,
}) async {
  bool inRange(DateTime d) =>
      !d.isBefore(DateTime(from.year, from.month, from.day)) &&
      d.isBefore(DateTime(to.year, to.month, to.day).add(const Duration(days: 1)));

  final people = {for (final p in await db.allPeople()) p.id: p};
  final out = <AgendaEntry>[];

  for (final m in await db.allMeetings()) {
    if (!inRange(m.startsAt)) continue;
    final who = people[m.personId]?.name;
    out.add(AgendaEntry(
      at: m.startsAt,
      kind: 'meeting',
      title: m.title,
      subtitle: [
        fmtClock(m.startsAt),
        ?who,
        if ((m.location ?? '').isNotEmpty) m.location!,
      ].join(' · '),
      personId: m.personId,
      meeting: m,
      hasTime: true,
    ));
  }

  for (final o in await db.allOccasions()) {
    if (!inRange(o.date)) continue;
    final tagged =
        people.values.where((p) => p.occasionTags.contains(o.tag)).length;
    out.add(AgendaEntry(
      at: o.date,
      kind: 'occasion',
      title: o.name,
      // Reuses the shared helper so the plural cannot drift again.
      subtitle: taggedLabelFor(tagged),
    ));
  }

  for (final p in people.values) {
    if (p.pingDate == null || !inRange(p.pingDate!)) continue;
    out.add(AgendaEntry(
      at: p.pingDate!,
      kind: 'ping',
      title: 'Ping: ${p.name}',
      subtitle: p.pingNote ?? 'no note',
      personId: p.id,
    ));
  }

  for (final t in await db.allTouches()) {
    if (!inRange(t.date)) continue;
    out.add(AgendaEntry(
      at: t.date,
      kind: 'touch',
      title: people[t.personId]?.name ?? 'Someone',
      subtitle: t.oneLine,
      personId: t.personId,
    ));
  }

  for (final m in await db.allMoney()) {
    if (!inRange(m.date)) continue;
    out.add(AgendaEntry(
      at: m.date,
      kind: 'money',
      title: m.label,
      subtitle: '${fmtMoney(m.amountMinor, m.currency)} ${m.direction} · '
          '${m.status}',
    ));
  }

  // ⚠ Timed entries sort ahead of whole-day ones within the same day, so a
  // 15:00 meeting does not appear above a festival it happens to share a day
  // with purely by insertion order.
  out.sort((a, b) {
    final d = a.day.compareTo(b.day);
    if (d != 0) return d;
    if (a.hasTime != b.hasTime) return a.hasTime ? -1 : 1;
    return a.at.compareTo(b.at);
  });
  return out;
}

/// Groups an agenda into days, preserving order and skipping empty ones.
Map<DateTime, List<AgendaEntry>> byDay(List<AgendaEntry> entries) {
  final out = <DateTime, List<AgendaEntry>>{};
  for (final e in entries) {
    out.putIfAbsent(e.day, () => []).add(e);
  }
  return out;
}
