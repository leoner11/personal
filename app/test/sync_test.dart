import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/notifications.dart';
import 'package:personal_crm/domain/sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An in-memory stand-in for server/core/sync.py, faithful on the three
/// behaviours sync correctness depends on:
///   * a push stores every row it receives and stamps it NOW, newest wins;
///   * a pull returns rows with updated_at strictly after `since`;
///   * `server_time` is read BEFORE the query, exactly as the view does.
/// JSON the way Django's JsonResponse writes it: `ensure_ascii`, every
/// non-ASCII character escaped as \uXXXX. That is what makes the real
/// responses safe for package:http, which decodes a body with no charset as
/// Latin-1 — a raw 春节 in the fake would throw where production cannot.
String asciiJson(Object? value) {
  final raw = jsonEncode(value);
  final out = StringBuffer();
  for (final unit in raw.codeUnits) {
    out.write(unit < 128
        ? String.fromCharCode(unit)
        : '\\u${unit.toRadixString(16).padLeft(4, '0')}');
  }
  return out.toString();
}

class FakeServer {
  /// Account (the bearer token) → table → id → row. Owner-scoped, like the
  /// real server: one account can never see another's rows.
  final accounts = <String, Map<String, Map<String, Map<String, dynamic>>>>{};

  /// The default account's rows, for tests that only need one.
  Map<String, Map<String, Map<String, dynamic>>> get rows => of('leonard');
  Map<String, Map<String, Map<String, dynamic>>> of(String account) =>
      accounts[account] ??= {};

  /// Every push body received, in order: table → rows.
  final pushes = <Map<String, List<Map<String, dynamic>>>>[];

  int pushStatus = 200;
  int pullStatus = 200;

  /// Runs after the server has stamped a push but before it answers — the
  /// window in which a user can still edit on the device.
  Future<void> Function()? beforePushResponds;

  final _epoch = DateTime.utc(2026, 9, 1);
  var _tick = 0;
  String now() =>
      _epoch.add(Duration(milliseconds: ++_tick * 10)).toIso8601String();

  late final http.Client client = MockClient((req) async {
    final rows =
        of((req.headers['Authorization'] ?? '').replaceFirst('Bearer ', ''));
    if (req.method == 'POST') {
      if (pushStatus != 200) return http.Response('nope', pushStatus);
      final tables = (jsonDecode(req.body) as Map)['tables'] as Map;
      final received = <String, List<Map<String, dynamic>>>{};
      final stamped = <String, List<Map<String, dynamic>>>{};
      for (final e in tables.entries) {
        final table = e.key as String;
        for (final raw in e.value as List) {
          final row = Map<String, dynamic>.from(raw as Map)
            ..['updated_at'] = now();
          (rows[table] ??= {})[row['id'] as String] = row;
          (received[table] ??= []).add(row);
          (stamped[table] ??= []).add(row);
        }
      }
      pushes.add(received);
      final hook = beforePushResponds;
      if (hook != null) await hook();
      return http.Response(asciiJson({'tables': stamped}), 200);
    }

    if (pullStatus != 200) return http.Response('nope', pullStatus);
    final serverTime = now();
    final since = req.url.queryParameters['since'];
    final after = since == null ? null : DateTime.parse(since);
    final out = <String, List<Map<String, dynamic>>>{};
    for (final e in rows.entries) {
      out[e.key] = [
        for (final r in e.value.values)
          if (after == null ||
              DateTime.parse(r['updated_at'] as String).isAfter(after))
            r,
      ];
    }
    return http.Response(
        asciiJson({'server_time': serverTime, 'tables': out}), 200);
  });
}

class Device {
  Device(this.name, this.server, {String account = 'leonard'})
      : db = AppDatabase.forTesting(NativeDatabase.memory()) {
    signIn(account);
  }

  final String name;
  final FakeServer server;
  final AppDatabase db;
  late SyncEngine engine;

  /// A fresh sign-in: a new engine, as the shells build one per sync.
  void signIn(String account) {
    engine = SyncEngine(db,
        baseUrl: 'https://crm.test',
        token: account,
        client: server.client,
        lastSyncedKey: 'last_synced_$name');
  }

  Future<List<String>> names() async =>
      [for (final p in await db.allPeople()) p.name]..sort();

  Future<DateTime?> sync() => engine.run();

  Future<String> addPerson(String name) async {
    final id = newId();
    await db.addPerson(PeopleCompanion.insert(id: Value(id), name: name));
    return id;
  }

  Future<Person> person(String id) async =>
      (await db.select(db.people).get()).firstWhere((p) => p.id == id);
}

void main() {
  late FakeServer server;
  late Device mac, phone;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    server = FakeServer();
    mac = Device('mac', server);
    phone = Device('phone', server);
  });
  tearDown(() async {
    await mac.db.close();
    await phone.db.close();
  });

  int pushCount() => server.pushes.length;

  test('a first sync uploads everything once, and the next uploads nothing',
      () async {
    await mac.addPerson('Pak Andi');
    await mac.addPerson('Sri');

    expect(await mac.sync(), isNotNull);
    expect(server.pushes.single['people']!.length, 2);

    // Nothing changed: no request at all, not an empty one.
    expect(await mac.sync(), isNotNull);
    expect(pushCount(), 1);
  });

  test('an edit uploads only the row that changed', () async {
    final andi = await mac.addPerson('Pak Andi');
    await mac.addPerson('Sri');
    await mac.addPerson('Mr Tan');
    await mac.sync();

    await mac.db.updatePerson(
        andi, const PeopleCompanion(company: Value('PT Formcase')));
    await mac.sync();

    expect(server.pushes.last.keys, ['people']);
    expect(server.pushes.last['people']!.single['id'], andi);
  });

  test('a stale device no longer overwrites a newer edit from the other device',
      () async {
    // ⚠ THE BUG THIS WHOLE CHANGE EXISTS FOR. Sync used to upload every row
    // every time, and the server takes whatever arrives last as newest — so the
    // Mac, still holding "Sri", erased the phone's correction just by syncing.
    final sri = await phone.addPerson('Sri');
    await phone.sync();
    await mac.sync();
    expect((await mac.person(sri)).name, 'Sri');

    await phone.db.updatePerson(
        sri, const PeopleCompanion(name: Value('Sri Wahyuni')));
    await phone.sync();

    final before = pushCount();
    await mac.sync(); // the stale device

    expect(pushCount(), before, reason: 'the Mac changed nothing, so sends nothing');
    expect(server.rows['people']![sri]!['name'], 'Sri Wahyuni');
    expect((await mac.person(sri)).name, 'Sri Wahyuni');
  });

  test('rows pulled from the server are not uploaded back', () async {
    // Counting pulled rows as local edits would push them straight back,
    // restamped, for the other device to pull and push again — forever.
    for (final n in ['A', 'B', 'C', 'D', 'E']) {
      await phone.addPerson(n);
    }
    await phone.sync();
    await mac.sync();
    expect((await mac.db.allPeople()).length, 5);

    final before = pushCount();
    await mac.sync();
    await phone.sync();
    expect(pushCount(), before);
  });

  test('an edit made while the upload is in flight is kept, and goes up next',
      () async {
    final andi = await mac.addPerson('Andi');
    var once = true;
    server.beforePushResponds = () async {
      if (!once) return;
      once = false;
      await mac.db.updatePerson(
          andi, const PeopleCompanion(name: Value('Pak Andi')));
    };

    await mac.sync();
    // The pull brought back the server's older "Andi" — it must not win.
    expect((await mac.person(andi)).name, 'Pak Andi');
    expect(server.rows['people']![andi]!['name'], 'Andi');

    await mac.sync();
    expect(server.rows['people']![andi]!['name'], 'Pak Andi');
  });

  test('a failed upload keeps rows pending and does not advance the sync point',
      () async {
    server.pushStatus = 500;
    await mac.addPerson('Pak Andi');

    expect(await mac.sync(), isNull);
    expect(server.rows['people'], isNull);
    expect((await SharedPreferences.getInstance()).getString('last_synced_mac'),
        isNull);

    server.pushStatus = 200;
    expect(await mac.sync(), isNotNull);
    expect(server.rows['people']!.length, 1);
  });

  test('a delete on one device reaches the other', () async {
    final tan = await phone.addPerson('Mr Tan');
    await phone.sync();
    await mac.sync();

    await phone.db.softDelete(tan);
    await phone.sync();
    await mac.sync();

    expect((await mac.person(tan)).deletedAt, isNotNull);
    expect(await mac.db.allPeople(), isEmpty);
  });

  test('a row committed just behind the last sync point is still picked up',
      () async {
    // The server reads server_time before querying; a push from the other
    // device can commit a row stamped just before that time after the query
    // ran. Without the overlap the next pull starts after it and never sees it.
    await mac.sync();
    final since = DateTime.parse(
        (await SharedPreferences.getInstance()).getString('last_synced_mac')!);
    server.rows['people'] = {
      'late': {
        'id': 'late',
        'name': 'Committed late',
        'updated_at':
            since.subtract(const Duration(milliseconds: 1)).toIso8601String(),
      },
    };

    await mac.sync();
    expect((await mac.person('late')).name, 'Committed late');
  });

  test('every synced table is tracked — none can be forgotten', () async {
    final db = mac.db;
    final pid = await mac.addPerson('Pak Andi');
    await seedBuiltInTags(db);
    await db.into(db.occasions).insert(OccasionsCompanion.insert(
        name: 'Deepavali', date: DateTime(2027, 10, 29), tag: 'deepavali'));
    await db.into(db.engagements).insert(
        EngagementsCompanion.insert(name: 'Ralali JV'));
    await db.addMoney(MoneyCompanion.insert(
        date: DateTime(2026, 9, 1),
        direction: 'in',
        amountMinor: 100,
        label: 'Deposit'));
    await db.into(db.notes).insert(NotesCompanion.insert(date: DateTime.now()));
    await db.logTouch(pid, 'called');
    await db.addMeeting(MeetingsCompanion.insert(
        title: 'Coffee', startsAt: DateTime(2026, 9, 20, 10)));
    await db.addTask(TasksCompanion.insert(title: 'Send the quotation'));

    await mac.sync();

    // ⚠ Compared against the database's own list, which the triggers are built
    // from — so a table added there but not tracked fails here.
    expect(server.pushes.single.keys.toSet(),
        db.syncedTables.map((t) => t.actualTableName).toSet());
  });
}
