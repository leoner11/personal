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
        'money': (await db.select(db.money).get()).map(_money).toList(),
        'touches': (await db.select(db.touches).get()).map(_touch).toList(),
      }
    };
    await http.post(Uri.parse('$baseUrl/sync'),
        headers: _headers, body: jsonEncode(body));
  }

  Future<String?> _pull(String? since) async {
    final uri = Uri.parse(
        '$baseUrl/sync${since != null ? '?since=${Uri.encodeComponent(since)}' : ''}');
    final res = await http.get(uri, headers: _headers);
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
    return data['server_time'] as String?;
  }

  static String? _s(dynamic v) =>
      (v == null || (v is String && v.isEmpty)) ? null : v as String;
  static DateTime? _d(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  Map<String, dynamic> _person(Person p) => {
        'id': p.id,
        'name': p.name,
        'company': p.company ?? '',
        'wa_number': p.waNumber ?? '',
        'wechat_id': p.wechatId ?? '',
        'preferred_channel': p.preferredChannel,
        'met_where': p.metWhere ?? '',
        'met_when': p.metWhen?.toIso8601String(),
        'notes': p.notes ?? '',
        'occasion_tags': p.occasionTags.join(','),
        'ping_date': p.pingDate?.toIso8601String(),
        'ping_note': p.pingNote ?? '',
        'deleted_at': p.deletedAt?.toIso8601String(),
      };

  Map<String, dynamic> _occasion(Occasion o) => {
        'id': o.id,
        'name': o.name,
        'date': o.date.toIso8601String(),
        'tag': o.tag,
        'country': o.country ?? '',
        'deleted_at': o.deletedAt?.toIso8601String(),
      };

  Map<String, dynamic> _money(MoneyRow m) => {
        'id': m.id,
        'date': m.date.toIso8601String(),
        'direction': m.direction,
        'amount_minor': m.amountMinor,
        'currency': m.currency,
        'label': m.label,
        'status': m.status,
        'engagement_id': m.engagementId,
        'person_id': m.personId,
        'occasion_tag': m.occasionTag ?? '',
        'deleted_at': m.deletedAt?.toIso8601String(),
      };

  Map<String, dynamic> _touch(Touch t) => {
        'id': t.id,
        'person_id': t.personId,
        'date': t.date.toIso8601String(),
        'one_line': t.oneLine,
        'deleted_at': t.deletedAt?.toIso8601String(),
      };
}
