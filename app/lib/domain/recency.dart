import '../data/database.dart';

/// C1 — the forgotten-person loop. Grouping people by how long it has been is
/// the whole point of the People list, so what "recent" means is domain logic,
/// not layout. Both shells read it from here or they will drift.
///
/// Ordered deliberately: NEVER goes last, not first. It is usually the largest
/// bucket right after an import, and leading with it buries the people you
/// actually have a relationship with.
Map<String, List<Person>> groupByRecency(
  List<Person> people,
  Map<String, DateTime> lastTouch, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final buckets = <String, List<Person>>{
    'RECENT': [],
    '1–3 MO': [],
    '3–6 MO': [],
    '6 MO+': [],
    'NEVER': [],
  };
  for (final p in people) {
    final lt = lastTouch[p.id];
    if (lt == null) {
      buckets['NEVER']!.add(p);
      continue;
    }
    final d = at.difference(lt).inDays;
    if (d < 30) {
      buckets['RECENT']!.add(p);
    } else if (d < 90) {
      buckets['1–3 MO']!.add(p);
    } else if (d < 180) {
      buckets['3–6 MO']!.add(p);
    } else {
      buckets['6 MO+']!.add(p);
    }
  }
  return buckets;
}
