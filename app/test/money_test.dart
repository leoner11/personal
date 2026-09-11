import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/domain/money_fmt.dart';
import 'package:personal_crm/domain/notifications.dart';
import 'package:personal_crm/domain/occasions.dart';

void main() {
  group('money is integer minor units, never floats', () {
    test('CNY/USD/MYR use two decimals, IDR uses none', () {
      expect(toMinor('400', 'CNY'), 40000);
      expect(toMinor('400.50', 'CNY'), 40050);
      expect(toMinor('2500000', 'IDR'), 2500000);
    });

    test('formats with thousands separators and the right symbol', () {
      expect(fmtMoney(2500000, 'CNY'), '¥25,000.00');
      expect(fmtMoney(2500000, 'IDR'), 'Rp2,500,000');
      expect(fmtMoney(42000, 'USD'), '\$420.00');
      expect(fmtMoney(-42000, 'USD'), '-\$420.00');
    });

    test('round-trips a typed amount without drifting', () {
      // The float trap: 0.1 + 0.2 style error must never reach a balance.
      var total = 0;
      for (var i = 0; i < 10; i++) {
        total += toMinor('0.10', 'CNY');
      }
      expect(fmtMoney(total, 'CNY'), '¥1.00');
    });
  });

  group('date formatting', () {
    test('omits the year when it is this year, includes it otherwise', () {
      final thisYear = DateTime(DateTime.now().year, 9, 8);
      expect(fmtDate(thisYear), '8 Sep');
      expect(fmtDate(DateTime(2025, 9, 8)), '8 Sep 2025');
    });

    test('fmtIn counts whole calendar days', () {
      final n = DateTime.now();
      expect(fmtIn(DateTime(n.year, n.month, n.day)), 'today');
      expect(fmtIn(DateTime(n.year, n.month, n.day).add(const Duration(days: 1))),
          'tomorrow');
    });
  });

  group('taggedLabel', () {
    // ⚠ This string is read by a human — on a lock screen months from now, or
    // on the Today card the notification opens onto. It was fixed in the
    // notification body on 10 Sep and stayed broken on both Today screens
    // until 11 Sep, because it was written out three times.
    test('one person is a person', () => expect(taggedLabel(1), '1 person tagged'));
    test('everything else is people', () {
      expect(taggedLabel(0), '0 people tagged');
      expect(taggedLabel(2), '2 people tagged');
    });
  });

  group('occasion seed', () {
    test('covers three years past today and gives a runway into 2029', () {
      final dates = kSeedOccasions.map((e) => e.$2).toList()..sort();
      expect(dates.last.year, greaterThanOrEqualTo(2029));
      // ⚠ The silent failure: if the seed is short, nothing fires and it
      // looks exactly like a quiet day.
      expect(dates.last.difference(DateTime(2026, 9, 9)).inDays,
          greaterThan(365 * 2));
    });

    test('every seeded row maps to a real OccasionTag', () {
      for (final row in kSeedOccasions) {
        expect(OccasionTag.fromId(row.$3.name), isNotNull,
            reason: '${row.$1} has an unmappable tag');
      }
    });

    test('one occasion per tag per year, never two', () {
      // ⚠ backfillSeedOccasions dedupes on (tag, year). A seed carrying two
      // rows for one tag in one year would leave the second permanently
      // unseeded on an existing database, silently.
      final seen = <(String, int)>{};
      for (final row in kSeedOccasions) {
        final key = (row.$3.name, row.$2.year);
        expect(seen.contains(key), isFalse,
            reason: '${row.$1} duplicates ${row.$3.name} in ${row.$2.year}');
        seen.add(key);
      }
    });

    test('the two CN additions are seeded for the years still ahead', () {
      // 端午节 2026 fell on 19 June and is deliberately absent.
      final duanwu = kSeedOccasions
          .where((e) => e.$3 == OccasionTag.duanwu)
          .map((e) => e.$2.year)
          .toList();
      expect(duanwu, [2027, 2028]);

      // 国庆节 is a fixed date, so every year it is seeded for is 1 October.
      final guoqing =
          kSeedOccasions.where((e) => e.$3 == OccasionTag.guoqing).toList();
      expect(guoqing.map((e) => e.$2.year).toList(), [2026, 2027, 2028]);
      for (final g in guoqing) {
        expect((g.$2.month, g.$2.day), (10, 1));
      }
    });

    test('中秋节 2026 seed matches the hardcoded Phase 1 constant', () {
      final midAutumn2026 = kSeedOccasions.firstWhere(
          (e) => e.$3 == OccasionTag.midAutumn && e.$2.year == 2026);
      expect(midAutumn2026.$2, kMidAutumn2026);
    });
  });
}
