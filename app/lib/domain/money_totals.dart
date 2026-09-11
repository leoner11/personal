import '../data/database.dart';

/// The three numbers every money surface shows, derived in one place.
///
/// ⚠ Extracted because it was about to exist three times — the Mac screen, the
/// phone screen and the Review hub. The last string this project duplicated
/// three times ("1 people tagged") was fixed in one copy and stayed broken in
/// the other two for a day. A balance getting the same treatment would be a
/// good deal worse than a plural.
class MoneyTotals {
  const MoneyTotals(this.balances, this.inExpected, this.outExpected);

  /// Sum of ACTUALS only, per currency, signed by direction.
  ///
  /// ⚠ Never converted between currencies and never totalled across them.
  /// There is no rate in this app and inventing one would make the single
  /// number the screen exists to show a number that is not true.
  final Map<String, int> balances;

  /// Expected money in, per currency. Unsigned — the direction is the bucket.
  final Map<String, int> inExpected;

  /// Expected money out, per currency. Unsigned.
  final Map<String, int> outExpected;

  static MoneyTotals of(List<MoneyRow> rows) {
    final balances = <String, int>{};
    final inExpected = <String, int>{};
    final outExpected = <String, int>{};
    for (final m in rows) {
      if (m.status == 'actual') {
        final sign = m.direction == 'in' ? 1 : -1;
        balances[m.currency] =
            (balances[m.currency] ?? 0) + sign * m.amountMinor;
      } else {
        final bucket = m.direction == 'in' ? inExpected : outExpected;
        bucket[m.currency] = (bucket[m.currency] ?? 0) + m.amountMinor;
      }
    }
    return MoneyTotals(balances, inExpected, outExpected);
  }
}
