import '../data/database.dart';
import 'money_fmt.dart';

/// What is due. Shared by both shells — this is domain logic, not layout, and
/// the phone must not drift from the Mac about what "today" means.
class TodayData {
  TodayData({
    required this.occasions,
    required this.pings,
    required this.settle,
    required this.taggedCounts,
    required this.runwayWarning,
  });
  final List<Occasion> occasions;
  final List<Person> pings;
  final List<MoneyRow> settle;
  final Map<String, int> taggedCounts;
  final String? runwayWarning;

  int get count =>
      occasions.length +
      pings.length +
      settle.length +
      (runwayWarning == null ? 0 : 1);

  bool get isEmpty => count == 0;
}

Future<TodayData> loadToday(AppDatabase db) async {
  final now = DateTime.now();
  final occ = await db.upcomingOccasions(withinDays: 14);
  final people = await db.allPeople();
  final pings = people
      .where((p) =>
          p.pingDate != null &&
          p.pingDate!.isBefore(now.add(const Duration(days: 1))))
      .toList();
  final moneyRows = await db.allMoney();
  final settle = moneyRows
      .where((m) =>
          m.status == 'expected' &&
          m.date.isBefore(now.add(const Duration(days: 1))))
      .toList();

  final counts = <String, int>{};
  for (final o in occ) {
    counts[o.tag] = people.where((p) => p.occasionTags.contains(o.tag)).length;
  }

  // ⚠ An empty or short calendar is the app's silent failure: nothing fires and
  // it looks exactly like a quiet day. This is the one item allowed to sit on
  // Today indefinitely.
  final runway = await db.calendarRunway();
  String? warn;
  if (runway == null) {
    warn = 'Occasion calendar is empty — nothing will ever fire.';
  } else if (runway.difference(now).inDays < 365) {
    warn = 'Occasion calendar ends ${fmtDate(runway)} — add more dates.';
  }

  return TodayData(
    occasions: occ,
    pings: pings,
    settle: settle,
    taggedCounts: counts,
    runwayWarning: warn,
  );
}
