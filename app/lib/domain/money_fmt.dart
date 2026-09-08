/// ⚠ Currencies are shown SEPARATELY and never converted. Converting invites a
/// rate source, a refresh job, and historical-rate questions. Three balances
/// is fine.
const kCurrencies = ['CNY', 'IDR', 'USD', 'MYR'];

/// IDR is quoted without minor units in practice; the rest use two.
const kDecimals = {'CNY': 2, 'USD': 2, 'MYR': 2, 'IDR': 0};

const kSymbols = {'CNY': '¥', 'USD': '\$', 'MYR': 'RM', 'IDR': 'Rp'};

int toMinor(String raw, String currency) {
  final d = kDecimals[currency] ?? 2;
  final v = double.tryParse(raw.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
  return (v * (d == 0 ? 1 : 100)).round();
}

String fmtMoney(int minor, String currency, {bool symbol = true}) {
  final d = kDecimals[currency] ?? 2;
  final neg = minor < 0;
  final abs = minor.abs();
  final whole = d == 0 ? abs : abs ~/ 100;
  final frac = d == 0 ? 0 : abs % 100;

  final s = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  final body = d == 0
      ? buf.toString()
      : '$buf.${frac.toString().padLeft(2, '0')}';
  return '${neg ? '-' : ''}${symbol ? (kSymbols[currency] ?? '') : ''}$body';
}

/// `8 Sep`, or `8 Sep 2025` if not this year. Never ISO, never 8/9/26 —
/// day-month order is ambiguous between the ID and CN contexts.
const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

String fmtDate(DateTime d) {
  final now = DateTime.now();
  final base = '${d.day} ${_months[d.month - 1]}';
  return d.year == now.year ? base : '$base ${d.year}';
}

/// Relative for recency, absolute for scheduled facts.
String fmtAgo(DateTime? d) {
  if (d == null) return 'never';
  final days = DateTime.now().difference(d).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 30) return '$days days ago';
  final months = (days / 30).floor();
  if (months < 12) return '$months mo ago';
  return '${(months / 12).floor()} yr ago';
}

String fmtIn(DateTime d) {
  final n = DateTime.now();
  final days = DateTime(d.year, d.month, d.day)
      .difference(DateTime(n.year, n.month, n.day))
      .inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days < 0) return '${-days} days ago';
  return 'in $days days';
}
