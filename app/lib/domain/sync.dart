import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart';

/// ⚠ LOCAL-FIRST. Sync failure is a silent no-op that retries later. It NEVER
/// blocks a screen and never shows an error the user must dismiss. The app
/// must work in a basement meeting room with no signal.
///
/// Single user, two devices. Last-write-wins is genuinely correct here —
/// all the horror of sync is concurrent edits by DIFFERENT PEOPLE.
class SyncEngine {
  SyncEngine(
    this.db, {
    required this.baseUrl,
    required this.token,
    http.Client? client,
    @visibleForTesting this.lastSyncedKey = _kLastSynced,
  }) : _http = client ?? http.Client();

  final AppDatabase db;
  final String baseUrl;
  final String token;
  final http.Client _http;

  /// Where the last server time is kept. Only tests change it — two simulated
  /// devices in one process would otherwise share a single stamp.
  final String lastSyncedKey;

  static const _kLastSynced = 'last_synced_at';

  /// ⚠ How far back each pull reaches before the last server time. The server
  /// reads `server_time` before querying, but a push from the OTHER device can
  /// commit a row stamped just before that time after the query has already
  /// run — and a pull strictly after `since` would then never see it. The
  /// overlap re-fetches those rows; the stamp check in [_pull] makes the
  /// repeats free.
  static const pullOverlap = Duration(minutes: 1);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<DateTime?> lastSynced() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(lastSyncedKey);
    return s == null ? null : DateTime.tryParse(s);
  }

  /// Push what changed here, then pull what changed elsewhere.
  /// Returns null on failure — the caller shows a quiet footer state, nothing more.
  ///
  /// ⚠ A FAILED PUSH STOPS THE RUN. The rows stay dirty and go up next time;
  /// pulling on top of an unpushed batch would work, but "the upload failed and
  /// the footer still says synced" is the lie this avoids.
  Future<DateTime?> run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final since = prefs.getString(lastSyncedKey);
      if (!await _push()) return null;
      final serverTime = await _pull(since);
      if (serverTime != null) {
        await prefs.setString(lastSyncedKey, serverTime);
      }
      return serverTime == null ? null : DateTime.tryParse(serverTime);
    } catch (_) {
      // Silent. Retries on the next launch or the next manual trigger.
      return null;
    }
  }

  /// Uploads ONLY rows changed on this device since the server last saw them.
  ///
  /// ⚠ THIS IS THE FIX FOR LOST EDITS. It used to upload every row of every
  /// table. The server stamps whatever arrives as newest, so a device holding
  /// a stale copy overwrote a newer edit from the other device just by
  /// syncing. A row this device did not change is now never sent, so it can
  /// never overwrite anything. What remains is honest last-writer-wins: the
  /// same row edited on BOTH devices before either syncs keeps whichever
  /// uploads last. One person, two devices — acceptable, and documented.
  ///
  /// Returns true when there was nothing to send or the server took it.
  Future<bool> _push() async {
    final body = <String, List<Map<String, dynamic>>>{};
    final sent = <String, Map<String, int>>{}; // table → id → counter sent

    for (final spec in _specs) {
      final dirty = await db.dirtyRows(spec.name);
      if (dirty.isEmpty) continue;

      final (encoded, found) = await spec.load(db, dirty.keys.toList());
      for (final id in dirty.keys) {
        if (!found.contains(id)) await db.forgetSyncState(spec.name, id);
      }
      if (encoded.isEmpty) continue;

      body[spec.name] = encoded;
      sent[spec.name] = {for (final id in found) id: dirty[id]!};
    }

    // Nothing changed here: no request at all. Most syncs, most of the time.
    if (body.isEmpty) return true;

    final res = await _http.post(Uri.parse('$baseUrl/sync'),
        headers: _headers, body: jsonEncode({'tables': body}));
    if (res.statusCode == 401) {
      unauthorized = true;
      return false;
    }
    if (res.statusCode != 200) return false;

    // The server answers with every row it stamped. Adopt ITS stamp — the pull
    // compares against it — and clear only rows untouched since they were read.
    final stamped =
        ((jsonDecode(res.body) as Map<String, dynamic>)['tables'] ?? {})
            as Map<String, dynamic>;
    for (final entry in stamped.entries) {
      final counters = sent[entry.key];
      if (counters == null) continue;
      for (final row in (entry.value as List)) {
        final id = row['id'] as String?;
        final stamp = row['updated_at'] as String?;
        final counter = counters[id];
        if (id == null || stamp == null || counter == null) continue;
        await db.ackPushed(entry.key, id, counter, stamp);
      }
    }
    return true;
  }

  /// Set when the server rejects our token. ⚠ A 401 is NOT a transient
  /// network failure to retry forever — the token was revoked or the account
  /// changed, and only signing in again fixes it. Without telling this apart
  /// the sidebar would say "Syncing…" indefinitely against a server that will
  /// never accept us, which is exactly the armed-and-dead state this project
  /// keeps having to design against.
  bool unauthorized = false;

  Future<String?> _pull(String? since) async {
    final reach = _reachBack(since);
    final uri = Uri.parse(
        '$baseUrl/sync${reach != null ? '?since=${Uri.encodeComponent(reach)}' : ''}');
    final res = await _http.get(uri, headers: _headers);
    if (res.statusCode == 401) {
      unauthorized = true;
      return null;
    }
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tables = (data['tables'] ?? {}) as Map<String, dynamic>;

    // ⚠ ONE TRANSACTION. It is exclusive, so no user edit can land between
    // the dirty check below and the write that follows it.
    await db.transaction(() async {
      for (final spec in _specs) {
        final rows = (tables[spec.name] as List?) ?? const [];
        if (rows.isEmpty) continue;
        final state = await db.syncStateFor(
            spec.name, [for (final r in rows) r['id'] as String]);

        for (final raw in rows) {
          final row = raw as Map<String, dynamic>;
          final id = row['id'] as String;
          final stamp = row['updated_at'] as String?;
          final here = state[id];

          // ⚠ AN UNPUSHED LOCAL EDIT WINS. It was made after this device last
          // saw the row and has not reached the server yet — typically an edit
          // made while this very sync's upload was in flight. Overwriting it
          // now would lose it; leaving it means it goes up next run and the
          // server takes it.
          if (here != null && here.dirty > 0) continue;
          // Already holding exactly this version: our own push echoing back,
          // or the overlap window re-fetching.
          if (here != null && stamp != null && here.serverStamp == stamp) {
            continue;
          }

          // ⚠ This order. The upsert fires the change trigger; markPulled
          // then marks the row clean. Swapped, it would stay dirty.
          await spec.upsert(db, row);
          if (stamp != null) await db.markPulled(spec.name, id, stamp);
        }
      }
    });

    return data['server_time'] as String?;
  }

  static String? _reachBack(String? since) {
    if (since == null) return null;
    final at = DateTime.tryParse(since);
    if (at == null) return since;
    return at.subtract(pullOverlap).toUtc().toIso8601String();
  }

  /// Every synced table, described once. Push and pull both iterate this, so
  /// the two can never disagree about which tables exist.
  late final List<_Spec> _specs = [
    _Spec<Person>(db.people, (r) => r.id, _person, (row) => PeopleCompanion(
          id: Value(row['id'] as String),
          name: Value(row['name'] ?? ''),
          company: Value(_s(row['company'])),
          waNumber: Value(_s(row['wa_number'])),
          wechatId: Value(_s(row['wechat_id'])),
          preferredChannel: Value(row['preferred_channel'] ?? 'wa'),
          metWhere: Value(_s(row['met_where'])),
          metWhen: Value(_d(row['met_when'])),
          notes: Value(_s(row['notes'])),
          occasionTags: Value((row['occasion_tags'] as String? ?? '').isEmpty
              ? const []
              : (row['occasion_tags'] as String).split(',')),
          pingDate: Value(_d(row['ping_date'])),
          pingNote: Value(_s(row['ping_note'])),
          updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
          deletedAt: Value(_d(row['deleted_at'])),
        )),
    _Spec<Occasion>(db.occasions, (r) => r.id, _occasion, (row) => OccasionsCompanion(
          id: Value(row['id'] as String),
          name: Value(row['name'] ?? ''),
          date: Value(_d(row['date']) ?? DateTime.now()),
          tag: Value(row['tag'] ?? ''),
          country: Value(_s(row['country'])),
          greeting: Value(_s(row['greeting'])),
          updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
          deletedAt: Value(_d(row['deleted_at'])),
        )),
    // ⚠ The vocabulary, not a join table. A tag arriving from the other device
    // is what makes a person's chips resolve there; without it the label falls
    // back to the raw slug and the chip cannot be toggled off.
    _Spec<OccasionTagRow>(db.occasionTags, (r) => r.id, _occasionTag,
        (row) => OccasionTagsCompanion(
              id: Value(row['id'] as String),
              slug: Value(row['slug'] ?? ''),
              label: Value(row['label'] ?? ''),
              hint: Value(_s(row['hint'])),
              greeting: Value(_s(row['greeting'])),
              sortOrder: Value((row['sort_order'] as int?) ?? 0),
              builtIn: Value(row['built_in'] == true),
              updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
              deletedAt: Value(_d(row['deleted_at'])),
            )),
    _Spec<Engagement>(db.engagements, (r) => r.id, _engagement,
        (row) => EngagementsCompanion(
              id: Value(row['id'] as String),
              name: Value(row['name'] ?? ''),
              type: Value(row['type'] ?? 'deal'),
              counterpartyId: Value(_s(row['counterparty_id'])),
              status: Value(_s(row['status'])),
              valueMinor: Value(row['value_minor'] as int?),
              currency: Value(_s(row['currency'])),
              notes: Value(_s(row['notes'])),
              updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
              deletedAt: Value(_d(row['deleted_at'])),
            )),
    _Spec<MoneyRow>(db.money, (r) => r.id, _money, (row) => MoneyCompanion(
          id: Value(row['id'] as String),
          date: Value(_d(row['date']) ?? DateTime.now()),
          direction: Value(row['direction'] ?? 'out'),
          amountMinor: Value(row['amount_minor'] as int? ?? 0),
          currency: Value(row['currency'] ?? 'CNY'),
          label: Value(row['label'] ?? ''),
          status: Value(row['status'] ?? 'expected'),
          engagementId: Value(_s(row['engagement_id'])),
          personId: Value(_s(row['person_id'])),
          occasionTag: Value(_s(row['occasion_tag'])),
          updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
          deletedAt: Value(_d(row['deleted_at'])),
        )),
    _Spec<Note>(db.notes, (r) => r.id, _note, (row) => NotesCompanion(
          id: Value(row['id'] as String),
          date: Value(_d(row['date']) ?? DateTime.now()),
          body: Value(row['text'] ?? ''),
          personId: Value(_s(row['person_id'])),
          engagementId: Value(_s(row['engagement_id'])),
          tag: Value(_s(row['tag'])),
          updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
          deletedAt: Value(_d(row['deleted_at'])),
        )),
    _Spec<Touch>(db.touches, (r) => r.id, _touch, (row) => TouchesCompanion(
          id: Value(row['id'] as String),
          personId: Value(row['person_id'] ?? ''),
          date: Value(_d(row['date']) ?? DateTime.now()),
          oneLine: Value(row['one_line'] ?? ''),
          updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
          deletedAt: Value(_d(row['deleted_at'])),
        )),
    _Spec<Meeting>(db.meetings, (r) => r.id, _meeting, (row) => MeetingsCompanion(
          id: Value(row['id'] as String),
          personId: Value(_s(row['person_id'])),
          engagementId: Value(_s(row['engagement_id'])),
          title: Value(row['title'] ?? ''),
          // ⚠ Meetings carry a TIME, unlike every other dated row here, so
          // the full timestamp has to survive the round trip.
          startsAt: Value(_d(row['starts_at']) ?? DateTime.now()),
          durationMinutes: Value(row['duration_minutes'] ?? 60),
          location: Value(_s(row['location'])),
          notes: Value(_s(row['notes'])),
          updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
          deletedAt: Value(_d(row['deleted_at'])),
        )),
    _Spec<Task>(db.tasks, (r) => r.id, _task, (row) => TasksCompanion(
          id: Value(row['id'] as String),
          title: Value(row['title'] ?? ''),
          notes: Value(_s(row['notes'])),
          createdAt: Value(_d(row['created_at']) ?? DateTime.now()),
          dueDate: Value(_d(row['due_date'])),
          doneAt: Value(_d(row['done_at'])),
          personId: Value(_s(row['person_id'])),
          engagementId: Value(_s(row['engagement_id'])),
          updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
          deletedAt: Value(_d(row['deleted_at'])),
        )),
  ];

  static String? _s(dynamic v) =>
      (v == null || (v is String && v.isEmpty)) ? null : v as String;
  /// ⚠ toLocal(), always. The server stores and returns UTC (Django has
  /// USE_TZ on), so a value parsed straight through stays a UTC DateTime —
  /// and drift then hands the UI 15:00 UTC, which is 23:00 in Haining. A
  /// meeting silently moved eight hours on its first sync.
  static DateTime? _d(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String)?.toLocal();

  Map<String, dynamic> _person(Person p) => {
        'id': p.id,
        'name': p.name,
        'company': p.company ?? '',
        'wa_number': p.waNumber ?? '',
        'wechat_id': p.wechatId ?? '',
        'preferred_channel': p.preferredChannel,
        'met_where': p.metWhere ?? '',
        'met_when': p.metWhen?.toUtc().toIso8601String(),
        'notes': p.notes ?? '',
        'occasion_tags': p.occasionTags.join(','),
        'ping_date': p.pingDate?.toUtc().toIso8601String(),
        'ping_note': p.pingNote ?? '',
        'deleted_at': p.deletedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _occasion(Occasion o) => {
        'id': o.id,
        'name': o.name,
        'date': o.date.toUtc().toIso8601String(),
        'tag': o.tag,
        'country': o.country ?? '',
        'greeting': o.greeting ?? '',
        'deleted_at': o.deletedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _occasionTag(OccasionTagRow t) => {
        'id': t.id,
        'slug': t.slug,
        'label': t.label,
        'hint': t.hint ?? '',
        'greeting': t.greeting ?? '',
        'sort_order': t.sortOrder,
        'built_in': t.builtIn,
        'deleted_at': t.deletedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _engagement(Engagement e) => {
        'id': e.id,
        'name': e.name,
        'type': e.type,
        'counterparty_id': e.counterpartyId ?? '',
        'status': e.status ?? '',
        'value_minor': e.valueMinor,
        'currency': e.currency ?? '',
        'notes': e.notes ?? '',
        'deleted_at': e.deletedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _note(Note n) => {
        'id': n.id,
        'date': n.date.toUtc().toIso8601String(),
        'text': n.body,
        'person_id': n.personId ?? '',
        'engagement_id': n.engagementId ?? '',
        'tag': n.tag ?? '',
        'deleted_at': n.deletedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _money(MoneyRow m) => {
        'id': m.id,
        'date': m.date.toUtc().toIso8601String(),
        'direction': m.direction,
        'amount_minor': m.amountMinor,
        'currency': m.currency,
        'label': m.label,
        'status': m.status,
        'engagement_id': m.engagementId,
        'person_id': m.personId,
        'occasion_tag': m.occasionTag ?? '',
        'deleted_at': m.deletedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _meeting(Meeting m) => {
        'id': m.id,
        'person_id': m.personId,
        'engagement_id': m.engagementId,
        'title': m.title,
        'starts_at': m.startsAt.toUtc().toIso8601String(),
        'duration_minutes': m.durationMinutes,
        'location': m.location,
        'notes': m.notes,
        'deleted_at': m.deletedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _task(Task t) => {
        'id': t.id,
        'title': t.title,
        'notes': t.notes ?? '',
        'created_at': t.createdAt.toUtc().toIso8601String(),
        'due_date': t.dueDate?.toUtc().toIso8601String(),
        'done_at': t.doneAt?.toUtc().toIso8601String(),
        'person_id': t.personId ?? '',
        'engagement_id': t.engagementId ?? '',
        'deleted_at': t.deletedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _touch(Touch t) => {
        'id': t.id,
        'person_id': t.personId,
        'date': t.date.toUtc().toIso8601String(),
        'one_line': t.oneLine,
        'deleted_at': t.deletedAt?.toUtc().toIso8601String(),
      };
}

/// One synced table: how to find its changed rows, send them, and take them in.
class _Spec<R> {
  _Spec(this.info, this.idOf, this.encode, this.decode);

  final TableInfo<Table, R> info;
  final String Function(R row) idOf;
  final Map<String, dynamic> Function(R row) encode;
  final Insertable<R> Function(Map<String, dynamic> row) decode;

  /// ⚠ The SQL table name IS the wire name ('people', 'occasion_tags', …) —
  /// the same string the triggers write into sync_state.tbl.
  String get name => info.actualTableName;

  /// The changed rows, encoded for the wire, plus which ids still exist.
  ///
  /// ⚠ THE TYPED WORK STAYS IN HERE. The engine holds these in a
  /// `List<_Spec>` — `_Spec<dynamic>` — and calling [idOf] or [encode] through
  /// that type fails at RUNTIME (`(Person) => String` is not a
  /// `(dynamic) => String`). Inside a method, R is the real type. The first
  /// draft called them from the engine; run()'s silent catch swallowed the
  /// error and every sync did nothing at all, with no sign of it.
  Future<(List<Map<String, dynamic>>, Set<String>)> load(
      AppDatabase db, List<String> ids) async {
    final rows = await _rowsById(db, ids);
    return ([for (final r in rows) encode(r)], {for (final r in rows) idOf(r)});
  }

  Future<List<R>> _rowsById(AppDatabase db, List<String> ids) async {
    final id = info.columnsByName['id']! as GeneratedColumn<String>;
    final out = <R>[];
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      out.addAll(await (db.select(info)..where((_) => id.isIn(chunk))).get());
    }
    return out;
  }

  Future<void> upsert(AppDatabase db, Map<String, dynamic> row) =>
      db.into(info).insertOnConflictUpdate(decode(row));
}
