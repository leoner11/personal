import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import 'notifications.dart';
import 'occasions.dart';
import 'sync.dart';
import 'tag_vocab.dart';

/// Which account the data on THIS DEVICE belongs to, and what to do when a
/// sign-in doesn't match it.
///
/// ⚠ WHY THIS EXISTS. Signing out clears only the token; the local database
/// stays, because the app is local-first. Without this, signing in as a
/// different account made the next sync upload every row of the old
/// account's data into the new one — someone else's contacts, silently — and
/// the old sync point meant the new account's older rows never came down.
/// The engine now refuses to sync until this device knows whose data it holds
/// (see [SyncEngine.run]).

/// The two answers to "this device and this account both have data".
enum JoinChoice {
  /// Upload everything here into the account, and bring the account's data
  /// down. Nothing is removed anywhere.
  combine,

  /// Remove this device's data (a backup copy is kept first) and replace it
  /// with the account's. Nothing from this device is uploaded.
  useAccount,
}

/// How much REAL data one side holds, per table (wire names).
///
/// ⚠ Seeded rows do not count. Every device and every account carries the
/// built-in tags and the festival calendar; counting them would ask "combine
/// or replace?" of someone who has never typed a thing.
class DataSummary {
  const DataSummary(this.counts);
  final Map<String, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);
  bool get isEmpty => total == 0;

  static const _nouns = <String, (String, String)>{
    'people': ('person', 'people'),
    'engagements': ('project', 'projects'),
    'notes': ('note', 'notes'),
    'money': ('money entry', 'money entries'),
    'meetings': ('meeting', 'meetings'),
    'tasks': ('task', 'tasks'),
    'occasions': ('occasion', 'occasions'),
    'occasion_tags': ('tag', 'tags'),
  };

  /// "18 people, 29 notes and 24 tasks". Touches are counted in [total] but
  /// not named — "3 logged contacts" means nothing to the person choosing.
  String describe() {
    final parts = [
      for (final e in _nouns.entries)
        if ((counts[e.key] ?? 0) > 0)
          '${counts[e.key]} ${counts[e.key] == 1 ? e.value.$1 : e.value.$2}',
    ];
    if (parts.isEmpty) return isEmpty ? 'nothing' : 'some activity history';
    if (parts.length == 1) return parts.single;
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }
}

/// Everything the UI needs to ask the question in plain words.
class JoinNeeded {
  const JoinNeeded({
    required this.account,
    required this.previousAccount,
    required this.here,
    required this.there,
  });

  final String account;

  /// The account this device's data last synced with, or null if it never
  /// has. When set, the question is really "you're switching accounts".
  final String? previousAccount;
  final DataSummary here;
  final DataSummary there;
}

Set<String> get _seededOccasionIds =>
    {for (final r in kSeedOccasions) seededId(occasionSeedKey(r.$1, r.$2))};

Future<DataSummary> localSummary(AppDatabase db) async {
  Future<int> live(String table, [String extra = '']) async => (await db
          .customSelect(
              'SELECT count(*) AS c FROM $table WHERE deleted_at IS NULL $extra')
          .getSingle())
      .read<int>('c');

  final seeded = _seededOccasionIds;
  final userOccasions =
      (await db.allOccasions()).where((o) => !seeded.contains(o.id)).length;

  return DataSummary({
    for (final t in ['people', 'engagements', 'money', 'notes', 'touches',
        'meetings', 'tasks'])
      t: await live(t),
    'occasions': userOccasions,
    'occasion_tags': await live('occasion_tags', 'AND built_in = 0'),
  });
}

DataSummary remoteSummary(Map<String, dynamic> tables) {
  final seeded = _seededOccasionIds;
  bool alive(Map r) => r['deleted_at'] == null || r['deleted_at'] == '';

  final counts = <String, int>{};
  for (final e in tables.entries) {
    final rows = (e.value as List).cast<Map>().where(alive);
    counts[e.key] = switch (e.key) {
      'occasions' => rows.where((r) => !seeded.contains(r['id'])).length,
      'occasion_tags' => rows.where((r) => r['built_in'] != true).length,
      _ => rows.length,
    };
  }
  return DataSummary(counts);
}

/// Applies the user's answer, syncs, and puts back what a replace removed.
///
/// Shared by both shells so "combine" and "use the account's data" cannot come
/// to mean different things on the phone and the Mac.
Future<DateTime?> completeJoin(
  AppDatabase db,
  SyncEngine engine,
  JoinChoice choice, {
  String? backupPath,
}) async {
  await engine.resolveJoin(choice, backupPath: backupPath);
  var at = await engine.run();

  if (choice == JoinChoice.useAccount) {
    // ⚠ The wipe took the built-in tags and festival calendar with it. The
    // account's own copies came down in the pull; this restores any it lacks
    // — an account made before tags existed, say — without resurrecting
    // anything it deleted (both functions respect soft-deleted slots).
    // Tags first: the occasion backfill skips tags that are not in the table.
    await seedBuiltInTags(db);
    await backfillSeedOccasions(db);
    if (at != null) at = await engine.run() ?? at;
  }

  await TagVocab.refresh(db);
  // Whole sets of people and occasions just arrived or left; the schedule is
  // derived from them.
  await appNotifierReschedule();
  return at;
}

/// The question, worded once for both shells.
({String title, String body}) joinQuestion(JoinNeeded j) {
  final prev = j.previousAccount;
  final switching = prev != null && prev != j.account;
  return (
    title: switching ? 'Switching to ${j.account}' : 'This device already has data',
    body: [
      'This device has ${j.here.describe()}'
          '${switching ? ', last synced with $prev' : ''}.',
      'The account ${j.account} has ${j.there.describe()}.',
      'Nothing syncs until you choose.',
    ].join(' '),
  );
}

String combineExplainer(JoinNeeded j) =>
    'Everything here is added to ${j.account}, and ${j.account}\'s data comes '
    'to this device. Nothing is removed.';

String useAccountExplainer(JoinNeeded j) => j.there.isEmpty
    // Switching into an empty account: "replace" really means "start fresh".
    ? 'Start this device fresh with ${j.account}, which is empty. A backup '
        'copy of this device\'s data is saved first.'
    : 'This device\'s data is replaced with ${j.account}\'s. A backup copy '
        'is saved on this device first.';

/// ⚠ Names what is about to leave the device, in numbers, before it goes.
({String title, String body}) replaceConfirm(JoinNeeded j) => (
      title: 'Replace this device\'s data?',
      body: 'Removes ${j.here.describe()} from this device and brings down '
          '${j.account}\'s data instead. A backup copy is saved first.',
    );

/// Where the pre-replace snapshot goes: beside the live database, stamped so
/// a second replace never overwrites the first backup.
Future<String> replaceBackupPath() async {
  final dir = await getApplicationDocumentsDirectory();
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dir.path}/personal_crm-before-replace-'
      '${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}${two(n.second)}.sqlite';
}
