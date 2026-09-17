import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/notifications.dart';
import 'package:personal_crm/domain/sync.dart';
import 'package:personal_crm/domain/sync_account.dart';
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
        account: account,
        client: server.client,
        lastSyncedKey: 'last_synced_$name',
        ownerKey: 'sync_owner_$name');
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

  group('joining an account', () {
    test('signing up with data already on the device uploads it without asking',
        () async {
      await mac.addPerson('Pak Andi');
      await mac.addPerson('Sri');

      expect(await mac.sync(), isNotNull);
      expect(mac.engine.pendingJoin, isNull);
      expect(server.rows['people']!.length, 2);
    });

    test('a device holding only the built-in calendar joins silently',
        () async {
      await mac.addPerson('Pak Andi');
      await mac.sync();

      // Seeds exist on every device; they must not trigger the question.
      await seedBuiltInTags(phone.db);
      await seedIfEmpty(phone.db);
      await phone.sync();

      expect(phone.engine.pendingJoin, isNull);
      expect(await phone.names(), ['Pak Andi']);
    });

    test('an account holding only the built-in calendar takes a device\'s data silently',
        () async {
      await seedBuiltInTags(mac.db);
      await seedIfEmpty(mac.db);
      await mac.sync(); // the account now holds seeds and nothing else

      await phone.addPerson('Mr Tan');
      await phone.sync();

      expect(phone.engine.pendingJoin, isNull);
      expect(server.rows['people']!.length, 1);
    });

    test('a second device with its own data is asked, and nothing syncs first',
        () async {
      await mac.addPerson('Pak Andi');
      await mac.addPerson('Sri');
      await mac.sync();
      await phone.addPerson('Mr Tan');
      final pushesBefore = server.pushes.length;

      expect(await phone.sync(), isNull);

      final join = phone.engine.pendingJoin!;
      expect(join.here.counts['people'], 1);
      expect(join.there.counts['people'], 2);
      expect(join.previousAccount, isNull);
      // ⚠ Not one row moved either way before the answer.
      expect(server.pushes.length, pushesBefore);
      expect(await phone.names(), ['Mr Tan']);
    });

    test('Combine both brings the two together, on the device and the account',
        () async {
      await mac.addPerson('Pak Andi');
      await mac.addPerson('Sri');
      await mac.sync();
      await phone.addPerson('Mr Tan');
      await phone.sync();

      await completeJoin(phone.db, phone.engine, JoinChoice.combine);
      await mac.sync();

      const all = ['Mr Tan', 'Pak Andi', 'Sri'];
      expect(await phone.names(), all);
      expect(await mac.names(), all);
      expect(server.rows['people']!.length, 3);
    });

    test("Use the account's data replaces this device's, and uploads none of it",
        () async {
      final andi = await mac.addPerson('Pak Andi');
      final sri = await mac.addPerson('Sri');
      await mac.sync();
      await phone.addPerson('Mr Tan');
      await phone.sync();

      final dir = Directory.systemTemp.createTempSync('join');
      addTearDown(() => dir.deleteSync(recursive: true));
      final backup = '${dir.path}/before.sqlite';

      await completeJoin(phone.db, phone.engine, JoinChoice.useAccount,
          backupPath: backup);

      expect(await phone.names(), ['Pak Andi', 'Sri']);
      // ⚠ Not even as a tombstone: soft-deleting instead of wiping would have
      // uploaded Mr Tan as a deleted row into the account.
      expect(server.rows['people']!.keys.toSet(), {andi, sri});
      // The wipe took the built-in vocabulary; it has to come back.
      expect((await phone.db.allOccasionTags()).length, greaterThanOrEqualTo(9));
      // The way back, if the choice was a mistake.
      final copy = AppDatabase.forTesting(NativeDatabase(File(backup)));
      expect([for (final p in await copy.allPeople()) p.name], ['Mr Tan']);
      await copy.close();
    });

    test("switching accounts never pours the old account's data into the new one",
        () async {
      // ⚠ THE BUG THIS STEP EXISTS FOR. Sign-out keeps local data (local-first)
      // so signing in as someone else used to upload all of it into their
      // account on the very next sync.
      await mac.addPerson('Pak Andi');
      await mac.sync(); // mac's data now belongs to leonard

      final sriServer = server.of('sri');
      mac.signIn('sri');
      expect(await mac.sync(), isNull);

      final join = mac.engine.pendingJoin!;
      expect(join.previousAccount, 'leonard');
      expect(sriServer['people'], isNull);
    });

    test('switching, then Combine, moves data both ways in full', () async {
      final andi = await mac.addPerson('Pak Andi');
      await mac.sync(); // clean under leonard now

      // Sri's account already holds a person from long before this device's
      // last sync point with leonard.
      server.of('sri')['people'] = {
        'old': {
          'id': 'old',
          'name': 'Bu Ratna',
          'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        },
      };

      mac.signIn('sri');
      await mac.sync();
      await completeJoin(mac.db, mac.engine, JoinChoice.combine);

      // ⚠ Already synced with leonard, so NOT dirty — Combine must re-queue it
      // or it never reaches sri.
      expect(server.of('sri')['people']!.keys, contains(andi));
      // ⚠ Older than leonard's sync point — Combine must reset it or this
      // never comes down.
      expect(await mac.names(), ['Bu Ratna', 'Pak Andi']);
    });

    test('switching into an EMPTY account still asks', () async {
      // Silent here would be the same bug: "sri has nothing, so upload".
      await mac.addPerson('Pak Andi');
      await mac.sync();

      mac.signIn('sri');
      expect(await mac.sync(), isNull);
      expect(mac.engine.pendingJoin!.there.isEmpty, isTrue);
      expect(server.of('sri')['people'], isNull);
    });

    test('signing back into the same account asks nothing', () async {
      final andi = await mac.addPerson('Pak Andi');
      await mac.sync();

      await mac.db.updatePerson(
          andi, const PeopleCompanion(company: Value('PT Formcase')));
      mac.signIn('leonard');
      expect(await mac.sync(), isNotNull);
      expect(mac.engine.pendingJoin, isNull);
      expect(server.pushes.last['people']!.single['company'], 'PT Formcase');
    });

    test('an unreachable server neither asks nor records whose data this is',
        () async {
      await mac.addPerson('Pak Andi');
      server.pullStatus = 500;

      expect(await mac.sync(), isNull);
      expect(mac.engine.pendingJoin, isNull);
      expect((await SharedPreferences.getInstance()).getString('sync_owner_mac'),
          isNull);
      expect(server.rows['people'], isNull);
    });
  });
}
