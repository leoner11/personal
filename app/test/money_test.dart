import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/domain/money_fmt.dart';
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

    test('中秋节 2026 seed matches the hardcoded Phase 1 constant', () {
      final midAutumn2026 = kSeedOccasions.firstWhere(
          (e) => e.$3 == OccasionTag.midAutumn && e.$2.year == 2026);
      expect(midAutumn2026.$2, kMidAutumn2026);
    });
  });
}
