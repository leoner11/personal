import 'dart:convert';
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
  SyncEngine(this.db, {required this.baseUrl, required this.token});

  final AppDatabase db;
  final String baseUrl;
  final String token;

  static const _kLastSynced = 'last_synced_at';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<DateTime?> lastSynced() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kLastSynced);
    return s == null ? null : DateTime.tryParse(s);
  }

  /// Push local changes, then pull everything changed since last sync.
  /// Returns null on failure — the caller shows a quiet footer state, nothing more.
  Future<DateTime?> run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final since = prefs.getString(_kLastSynced);

      await _push();
      final serverTime = await _pull(since);

      if (serverTime != null) {
        await prefs.setString(_kLastSynced, serverTime);
      }
      return serverTime == null ? null : DateTime.tryParse(serverTime);
    } catch (_) {
      // Silent. Retries on the next launch or the next manual trigger.
      return null;
    }
  }

  Future<void> _push() async {
    final body = {
      'tables': {
        'people': (await db.select(db.people).get()).map(_person).toList(),
        'occasions': (await db.select(db.occasions).get()).map(_occasion).toList(),
        'engagements':
            (await db.select(db.engagements).get()).map(_engagement).toList(),
        'money': (await db.select(db.money).get()).map(_money).toList(),
        'notes': (await db.select(db.notes).get()).map(_note).toList(),
        'touches': (await db.select(db.touches).get()).map(_touch).toList(),
        'meetings':
            (await db.select(db.meetings).get()).map(_meeting).toList(),
      }
    };
    await http.post(Uri.parse('$baseUrl/sync'),
        headers: _headers, body: jsonEncode(body));
  }

  /// Set when the server rejects our token. ⚠ A 401 is NOT a transient
  /// network failure to retry forever — the token was revoked or the account
  /// changed, and only signing in again fixes it. Without telling this apart
  /// the sidebar would say "Syncing…" indefinitely against a server that will
  /// never accept us, which is exactly the armed-and-dead state this project
  /// keeps having to design against.
  bool unauthorized = false;

  Future<String?> _pull(String? since) async {
    final uri = Uri.parse(
        '$baseUrl/sync${since != null ? '?since=${Uri.encodeComponent(since)}' : ''}');
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 401) {
      unauthorized = true;
      return null;
    }
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tables = (data['tables'] ?? {}) as Map<String, dynamic>;

    // Newest updated_at wins. Field-level merge is not needed at one user.
    for (final row in (tables['people'] as List? ?? [])) {
      await db.into(db.people).insertOnConflictUpdate(PeopleCompanion(
            id: Value(row['id'] as String),
            name: Value(row['name'] ?? ''),
            company: Value(_s(row['company'])),
            waNumber: Value(_s(row['wa_number'])),
            wechatId: Value(_s(row['wechat_id'])),
            preferredChannel: Value(row['preferred_channel'] ?? 'wa'),
            metWhere: Value(_s(row['met_where'])),
            metWhen: Value(_d(row['met_when'])),
            notes: Value(_s(row['notes'])),
            occasionTags: Value(
                (row['occasion_tags'] as String? ?? '').isEmpty
                    ? const []
                    : (row['occasion_tags'] as String).split(',')),
            pingDate: Value(_d(row['ping_date'])),
            pingNote: Value(_s(row['ping_note'])),
            updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
            deletedAt: Value(_d(row['deleted_at'])),
          ));
    }
    for (final row in (tables['occasions'] as List? ?? [])) {
      await db.into(db.occasions).insertOnConflictUpdate(OccasionsCompanion(
            id: Value(row['id'] as String),
            name: Value(row['name'] ?? ''),
            date: Value(_d(row['date']) ?? DateTime.now()),
            tag: Value(row['tag'] ?? ''),
            country: Value(_s(row['country'])),
            updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
            deletedAt: Value(_d(row['deleted_at'])),
          ));
    }

    for (final row in (tables['engagements'] as List? ?? [])) {
      await db.into(db.engagements).insertOnConflictUpdate(EngagementsCompanion(
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
          ));
    }

    for (final row in (tables['money'] as List? ?? [])) {
      await db.into(db.money).insertOnConflictUpdate(MoneyCompanion(
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
          ));
    }

    for (final row in (tables['notes'] as List? ?? [])) {
      await db.into(db.notes).insertOnConflictUpdate(NotesCompanion(
            id: Value(row['id'] as String),
            date: Value(_d(row['date']) ?? DateTime.now()),
            body: Value(row['text'] ?? ''),
            personId: Value(_s(row['person_id'])),
            engagementId: Value(_s(row['engagement_id'])),
            tag: Value(_s(row['tag'])),
            updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
            deletedAt: Value(_d(row['deleted_at'])),
          ));
    }

    for (final row in (tables['touches'] as List? ?? [])) {
      await db.into(db.touches).insertOnConflictUpdate(TouchesCompanion(
            id: Value(row['id'] as String),
            personId: Value(row['person_id'] ?? ''),
            date: Value(_d(row['date']) ?? DateTime.now()),
            oneLine: Value(row['one_line'] ?? ''),
            updatedAt: Value(_d(row['updated_at']) ?? DateTime.now()),
            deletedAt: Value(_d(row['deleted_at'])),
          ));
    }

    for (final row in (tables['meetings'] as List? ?? [])) {
      await db.into(db.meetings).insertOnConflictUpdate(MeetingsCompanion(
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
          ));
    }

    return data['server_time'] as String?;
  }

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
        'deleted_at': o.deletedAt?.toUtc().toIso8601String(),
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

  Map<String, dynamic> _touch(Touch t) => {
        'id': t.id,
        'person_id': t.personId,
        'date': t.date.toUtc().toIso8601String(),
        'one_line': t.oneLine,
        'deleted_at': t.deletedAt?.toUtc().toIso8601String(),
      };
}
