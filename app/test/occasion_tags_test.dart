import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/notifications.dart';
import 'package:personal_crm/domain/occasions.dart';
import 'package:personal_crm/domain/tag_vocab.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/phone/edit_person_sheet.dart';
import 'package:personal_crm/ui/phone/occasion_run_screen.dart';
import 'package:personal_crm/ui/phone/occasion_tag_sheets.dart';

/// The tag vocabulary as USER DATA. Until this existed the nine tags were a
/// compiled-in enum covering Indonesian, Malaysian and Chinese contacts —
/// which made the app unusable for anyone else, and unfixably so: no chip
/// means no way to tag, and an untagged contact is a festival that never
/// fires.
void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedBuiltInTags(db);
    await TagVocab.refresh(db);
  });
  tearDown(() async {
    await TagVocab.reset();
    await db.close();
  });

  Widget host(Widget child) =>
      MaterialApp(theme: buildTheme(Brightness.light), home: child);

  group('the seed', () {
    test('built-ins keep their enum names as slugs, so nothing migrates', () async {
      final slugs = (await db.allOccasionTags()).map((t) => t.slug).toSet();
      // ⚠ If this fails, every person, occasion and money row already written
      // has silently detached from its tag.
      expect(slugs, containsAll(OccasionTag.values.map((t) => t.name)));
    });

    test('is idempotent — a second pass adds nothing', () async {
      expect(await seedBuiltInTags(db), 0);
      expect((await db.allOccasionTags()).length, OccasionTag.values.length);
    });

    test('does not resurrect a tag the user deleted', () async {
      final row = (await db.allOccasionTags())
          .firstWhere((t) => t.slug == 'deepavali');
      await db.deleteOccasionTag(row.id);

      expect(await seedBuiltInTags(db), 0);
      expect((await db.allOccasionTags()).any((t) => t.slug == 'deepavali'),
          isFalse);
    });

    test('two devices derive the same id for the same tag', () async {
      // The Mac and the phone both seed offline, before either has reached the
      // server. Different ids here means sync keeps both and every chip doubles.
      final other = AppDatabase.forTesting(NativeDatabase.memory());
      await seedBuiltInTags(other);
      final mine = {for (final t in await db.allOccasionTags()) t.slug: t.id};
      final theirs = {for (final t in await other.allOccasionTags()) t.slug: t.id};
      expect(mine, theirs);
      await other.close();
    });
  });

  group('creating a tag', () {
    test('mints a slug and lands after the built-ins', () async {
      final slug = await createOccasionTag(db, label: 'Hanukkah');
      expect(slug, 'hanukkah');
      final row = TagVocab.bySlug('hanukkah')!;
      expect(row.builtIn, isFalse);
      expect(row.sortOrder, greaterThanOrEqualTo(OccasionTag.values.length));
    });

    test('a CJK-only label still gets a stable, non-empty slug', () async {
      // '光明节' slugs to nothing in ascii; without the hash fallback every
      // CJK tag would collide on the empty string.
      final a = tagSlug('光明节');
      expect(a, isNotEmpty);
      expect(a, tagSlug('光明节'));
      expect(a, isNot(tagSlug('春分')));
    });

    test('the same label twice converges instead of drawing two chips', () async {
      final first = await createOccasionTag(db, label: 'Hanukkah');
      final again = await createOccasionTag(db, label: '  hanukkah  ');
      expect(again, first);
      expect((await db.allOccasionTags()).where((t) => t.slug == 'hanukkah').length, 1);
    });

    test('adding back a deleted tag revives it rather than duplicating', () async {
      final slug = await createOccasionTag(db, label: 'Songkran');
      final row = TagVocab.bySlug(slug!)!;
      await db.deleteOccasionTag(row.id);

      final again = await createOccasionTag(db, label: 'Songkran');
      expect(again, slug);
      final rows = await db.allOccasionTagsIncludingDeleted();
      expect(rows.where((t) => t.slug == 'songkran').length, 1);
      expect(TagVocab.bySlug(slug)!.deletedAt, isNull);
    });
  });

  group('deleting a tag', () {
    test('cascades to people and occasions, but leaves money history alone',
        () async {
      final row =
          (await db.allOccasionTags()).firstWhere((t) => t.slug == 'cny');
      await db.addPerson(PeopleCompanion.insert(
          name: 'Mr Tan', occasionTags: const Value(['cny', 'christmas'])));
      await db.into(db.occasions).insert(OccasionsCompanion.insert(
          name: '春节', date: DateTime(2027, 2, 6), tag: 'cny'));
      await db.addMoney(MoneyCompanion.insert(
          date: DateTime(2027, 2, 6),
          direction: 'out',
          amountMinor: 50000,
          label: '春节 gift — Mr Tan',
          occasionTag: const Value('cny')));

      await db.deleteOccasionTag(row.id);

      // The tag comes off the person — but only that tag.
      expect((await db.allPeople()).single.occasionTags, ['christmas']);
      // Its dates go with it: leaving them would fire reminders for a tag with
      // nowhere left in the UI to explain them.
      expect((await db.allOccasions()).any((o) => o.tag == 'cny'), isFalse);
      // ⚠ Money is a record of what was spent. A vocabulary change does not
      // rewrite history.
      expect((await db.allMoney()).single.occasionTag, 'cny');
    });

    test('and its festivals stay gone on the next launch', () async {
      final row = (await db.allOccasionTags())
          .firstWhere((t) => t.slug == 'guoqing');
      await db.deleteOccasionTag(row.id);
      await TagVocab.refresh(db);

      // ⚠ The whole point of the (tag, year) guard in backfillSeedOccasions.
      // Without it the delete looks broken three years at a time.
      await backfillSeedOccasions(db);
      expect((await db.allOccasions()).any((o) => o.tag == 'guoqing'), isFalse);
    });

    test('usage counts are what the confirm promises', () async {
      await db.addPerson(PeopleCompanion.insert(
          name: 'A', occasionTags: const Value(['deepavali'])));
      await db.addPerson(PeopleCompanion.insert(
          name: 'B', occasionTags: const Value(['deepavali'])));
      await db.into(db.occasions).insert(OccasionsCompanion.insert(
          name: 'Deepavali', date: DateTime(2027, 10, 29), tag: 'deepavali'));

      expect(await db.occasionTagUsage('deepavali'), (2, 1));
    });
  });

  group('renaming', () {
    test('keeps the slug, so everyone already tagged follows', () async {
      final row = (await db.allOccasionTags())
          .firstWhere((t) => t.slug == 'lebaran');
      await db.addPerson(PeopleCompanion.insert(
          name: 'Pak Andi', occasionTags: const Value(['lebaran'])));

      await db.updateOccasionTag(
          row.id, const OccasionTagsCompanion(label: Value('Raya')));
      await TagVocab.refresh(db);

      expect(TagVocab.labelFor('lebaran'), 'Raya');
      // ⚠ Re-slugging on rename would detach this person silently.
      expect((await db.allPeople()).single.occasionTags, ['lebaran']);
    });
  });

  group('label resolution', () {
    test('falls back to the raw slug rather than inventing one', () async {
      expect(TagVocab.labelFor('cny'), '春节 Chinese New Year');
      expect(TagVocab.labelFor('not-a-tag'), 'not-a-tag');
    });

    test('a deleted tag still names itself, so money history stays readable',
        () async {
      final row = (await db.allOccasionTags())
          .firstWhere((t) => t.slug == 'deepavali');
      await db.deleteOccasionTag(row.id);
      await TagVocab.refresh(db);

      expect(TagVocab.live.any((t) => t.slug == 'deepavali'), isFalse);
      expect(TagVocab.labelFor('deepavali'), 'Deepavali');
    });
  });

  group('the default tag for a new occasion', () {
    test('is New Year — the safe universal fallback', () {
      expect(TagVocab.defaultSlug, OccasionTag.newYear.name);
    });

    test('falls back to a real tag when New Year has been deleted', () async {
      final row = (await db.allOccasionTags())
          .firstWhere((t) => t.slug == 'newYear');
      await db.deleteOccasionTag(row.id);
      await TagVocab.refresh(db);

      // ⚠ Must be a tag that EXISTS: defaulting to a deleted one saves an
      // occasion with no audience and no chip, which fires nothing.
      expect(TagVocab.defaultSlug, isNot('newYear'));
      expect(TagVocab.live.any((t) => t.slug == TagVocab.defaultSlug), isTrue);
    });
  });

  group('the edit sheet', () {
    testWidgets('keeps a tag the vocabulary does not know, instead of dropping it',
        (tester) async {
      // ⚠ THE REGRESSION THIS EXISTS FOR. The sheet used to skip unknown slugs
      // on load and then write its set back over the person on save, deleting
      // them. Harmless while tags were a compiled-in enum; routine data loss
      // once tags are user data that travel by sync — make a tag on the phone,
      // edit that person on the Mac before sync lands, and it was gone.
      await db.addPerson(PeopleCompanion.insert(
          name: 'Pak Andi',
          waNumber: const Value('628111'),
          occasionTags: const Value(['cny', 'from-a-newer-client'])));
      final person = (await db.allPeople()).single;

      await tester.pumpWidget(host(PhoneEditPersonSheet(db: db, person: person)));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Save'), 120,
          scrollable: find
              .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable))
              .last);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect((await db.allPeople()).single.occasionTags,
          containsAll(['cny', 'from-a-newer-client']));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('the greeting chain', () {
    // ⚠ MOST SPECIFIC WINS: occasion → tag → built-in template. The middle
    // link is what makes a user-defined tag usable at all: 'Hanukkah' has no
    // entry in kGreetings and never will, so without it every run for a tag
    // the user invented opens WhatsApp with an empty message box.
    Future<void> pumpRun(WidgetTester tester, Occasion o) async {
      await tester.pumpWidget(host(OccasionRunScreen(db: db, occasion: o)));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    Future<Occasion> seedRun(
        {required String tag, String? occasionGreeting}) async {
      await db.addPerson(PeopleCompanion.insert(
          name: 'Pak Andi',
          waNumber: const Value('628123456789'),
          occasionTags: Value([tag])));
      await db.into(db.occasions).insert(OccasionsCompanion.insert(
            name: 'Run',
            date: DateTime.now(),
            tag: tag,
            greeting: Value(occasionGreeting),
          ));
      return (await db.allOccasions()).single;
    }

    testWidgets('a user-made tag supplies the greeting the templates cannot',
        (tester) async {
      late Occasion o;
      await tester.runAsync(() async {
        await createOccasionTag(db,
            label: 'Hanukkah', greeting: 'Happy Hanukkah!');
        o = await seedRun(tag: 'hanukkah');
      });
      await pumpRun(tester, o);

      expect(find.text('Happy Hanukkah!'), findsOneWidget);
      // One string, so there is nothing to switch between.
      expect(find.text('EN'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets("the occasion's own greeting still beats the tag's",
        (tester) async {
      late Occasion o;
      await tester.runAsync(() async {
        await createOccasionTag(db,
            label: 'Hanukkah', greeting: 'Happy Hanukkah!');
        o = await seedRun(
            tag: 'hanukkah', occasionGreeting: 'Chag Sameach, Daniel.');
      });
      await pumpRun(tester, o);

      expect(find.text('Chag Sameach, Daniel.'), findsOneWidget);
      expect(find.text('Happy Hanukkah!'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('a built-in with no tag greeting keeps its language templates',
        (tester) async {
      late Occasion o;
      await tester.runAsync(() async => o = await seedRun(tag: 'cny'));
      await pumpRun(tester, o);

      expect(find.textContaining('恭喜发财'), findsOneWidget);
      // ⚠ The template path is the ONLY one with languages to offer.
      expect(find.text('EN'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('the manager', () {
    testWidgets('lists the vocabulary and opens a tag for editing',
        (tester) async {
      await tester.pumpWidget(host(PhoneOccasionTagsScreen(db: db)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lebaran / Aidilfitri'), findsOneWidget);
      expect(find.text('ID + MY Muslim'), findsOneWidget, reason: 'the hint');

      // ⚠ Nine tags do not fit a phone, which is exactly why the list has to
      // be the scrollable rather than a shrink-wrapped child of a Column.
      await tester.scrollUntilVisible(find.text('New Year'), 120,
          scrollable: find.byType(Scrollable).last);
      await tester.pump();
      expect(find.text('New Year'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
