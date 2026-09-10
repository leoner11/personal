import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/notifications.dart';
import 'package:personal_crm/domain/occasions.dart';

/// ⚠ Every device seeds its own occasion calendar on first launch, offline,
/// before it has ever reached the server. With random v4 ids the Mac and the
/// phone each mint 19 rows with identical content and different ids; sync then
/// keeps all 38 and every festival notifies twice. Seeded ids must therefore be
/// derived from content, not generated. This is the whole reason for
/// seededId() and it is invisible until a second device exists.
void main() {
  test('seeded ids are stable across calls', () {
    expect(seededId('occasion:春节:2027-02-06'),
        seededId('occasion:春节:2027-02-06'));
  });

  test('different occasions get different ids', () {
    expect(seededId('occasion:春节:2027-02-06'),
        isNot(seededId('occasion:春节:2028-01-26')));
  });

  test('the key ignores time of day, so timezones cannot split a row', () {
    // Two devices in different zones can disagree about the clock time of a
    // seeded date. They must not disagree about the id.
    expect(occasionSeedKey('中秋节', DateTime(2026, 9, 25, 0, 0)),
        occasionSeedKey('中秋节', DateTime(2026, 9, 25, 23, 59)));
  });

  test('two devices seeding independently produce identical ids', () async {
    // Two live databases at once is the point of this test, not a mistake.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
    final mac = AppDatabase.forTesting(NativeDatabase.memory());
    final phone = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(mac.close);
    addTearDown(phone.close);

    await seedIfEmpty(mac);
    await seedIfEmpty(phone);

    final a = (await mac.watchOccasions().first).map((o) => o.id).toList()
      ..sort();
    final b = (await phone.watchOccasions().first).map((o) => o.id).toList()
      ..sort();

    expect(a, isNotEmpty);
    expect(a.length, kSeedOccasions.length);
    // The whole point: a sync between these two collapses to one calendar.
    expect(a, b);
  });
}
