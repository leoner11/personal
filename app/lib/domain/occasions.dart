/// Phase 1: the occasion calendar is a hardcoded constant, not a table.
/// D3 and the three-year seed arrive in Phase 3.
library;

/// The tag set from the flowchart, A1-3. Contacts do NOT share festivals
/// across ID / MY / CN — this is why the field cannot be backfilled later.
enum OccasionTag {
  lebaran('Lebaran / Aidilfitri', 'ID + MY Muslim'),
  cny('春节 Chinese New Year', 'CN + MY/ID Chinese'),
  midAutumn('中秋节 Mid-Autumn', 'CN, some MY/ID Chinese'),
  christmas('Christmas', 'ID/MY Christian, some intl'),
  deepavali('Deepavali', 'MY Indian'),
  idulAdha('Idul Adha', 'ID/MY Muslim'),
  duanwu('端午节 Dragon Boat', 'CN'),
  guoqing('国庆节 National Day', 'CN'),
  newYear('New Year', 'safe universal fallback');

  const OccasionTag(this.label, this.hint);
  final String label;
  final String hint;

  static OccasionTag? fromId(String id) {
    for (final t in OccasionTag.values) {
      if (t.name == id) return t;
    }
    return null;
  }
}

/// Mints the stable key stored on people, occasions and money from a label.
///
/// ⚠ MUST BE DETERMINISTIC. Two devices offline, both adding 'Hanukkah', have
/// to arrive at the same slug — that is what lets seededId('tag:`<slug>`')
/// collapse them into one row instead of drawing the chip twice.
///
/// ⚠ CJK LABELS SLUG TO NOTHING. '中秋节' has no ascii to keep, and an empty
/// slug would collide with every other CJK tag. Those fall back to a hash of
/// the label, which is still identical on both devices. The nine built-ins
/// never come through here at all: they keep their enum names, which is what
/// spares every existing row a migration.
String tagSlug(String label) {
  final ascii = label
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (ascii.isNotEmpty) return ascii.length <= 40 ? ascii : ascii.substring(0, 40);

  var h = 0;
  for (final c in label.trim().runes) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return 'tag-${h.toRadixString(16)}';
}

/// The built-in vocabulary, as seed rows for the occasion_tags table.
///
/// ⚠ THE ENUM IS NO LONGER THE AUTHORITY — this is a seed, exactly like
/// [kSeedOccasions]. The runtime list of tags is whatever the table holds, so
/// a user can add Hanukkah, Songkran or Thanksgiving and delete every festival
/// they will never send. The enum survives only to seed this and to key
/// [kGreetings], and [OccasionTag.fromId] returns null for a user-made tag,
/// which every call site already handles.
///
/// ⚠ THE SLUG IS THE ENUM NAME. Not derived, not re-slugged. Change one and
/// every person, occasion and money row carrying it silently detaches.
List<(String slug, String label, String hint, int order)> get kBuiltInTags => [
      for (final (i, t) in OccasionTag.values.indexed)
        (t.name, t.label, t.hint, i),
    ];

/// ⚠ HARDCODED FOR PHASE 1. 中秋节 2026 = Friday 25 September.
/// Confirmed as the 15th day of the 8th lunar month.
/// Phase 3 replaces this with the occasions table, seeded three years out.
final kMidAutumn2026 = DateTime(2026, 9, 25);
const kMidAutumnTag = OccasionTag.midAutumn;

/// Greeting templates, per occasion × language (resolves flowchart Open Q4).
/// Phase 1 keeps them here; Phase 3 moves them onto the occasion row.
const kGreetings = <OccasionTag, Map<String, String>>{
  OccasionTag.midAutumn: {
    '中文': '中秋节快乐！祝您和家人团圆美满，身体健康。',
    'EN': 'Happy Mid-Autumn Festival! Wishing you and your family a warm reunion.',
    'BM': 'Selamat Hari Kuih Bulan! Semoga anda dan keluarga sentiasa sihat.',
  },
  OccasionTag.cny: {
    '中文': '新年快乐！恭喜发财，万事如意。',
    'EN': 'Happy Chinese New Year! Wishing you prosperity and good health.',
    'BM': 'Gong Xi Fa Cai! Semoga tahun baharu membawa kejayaan.',
  },
  OccasionTag.lebaran: {
    'BM': 'Selamat Hari Raya Aidilfitri, maaf zahir dan batin.',
    'EN': 'Selamat Hari Raya! Wishing you and your family a joyful celebration.',
  },
  OccasionTag.christmas: {
    'EN': 'Merry Christmas and a happy New Year to you and your family.',
    'BM': 'Selamat Hari Natal dan Tahun Baru!',
  },
  OccasionTag.deepavali: {
    'EN': 'Happy Deepavali! Wishing you light, joy and prosperity.',
  },
  OccasionTag.idulAdha: {
    'BM': 'Selamat Hari Raya Aidiladha.',
    'EN': 'Wishing you a blessed Eid al-Adha.',
  },
  OccasionTag.newYear: {
    'EN': 'Happy New Year! Wishing you a strong year ahead.',
    '中文': '新年快乐！祝您新的一年顺顺利利。',
  },
};

/// Three years of dates, hand-seeded. ⚠ No API can supply these.
///
/// ACCURACY — read before trusting a row:
///   FIXED    Christmas, New Year, and the Chinese lunar dates (春节, 中秋节)
///            are computed from published calendars and are reliable.
///   ESTIMATE Lebaran and Idul Adha depend on moon sighting. Indonesia fixes
///            Lebaran by sidang isbat 1–2 days prior; Malaysia sights
///            separately and can differ by a day. Deepavali varies by region.
///            These are seeded as best estimates and WILL drift by ±1–2 days.
///            Correct them when the real announcement lands — that is the
///            annual maintenance this app deliberately accepts.
///
/// Seeding three years converts a hard annual deadline into a two-year buffer.
final kSeedOccasions = <(String, DateTime, OccasionTag, String)>[
  // ── 2026 ──
  ('中秋节 Mid-Autumn', DateTime(2026, 9, 25), OccasionTag.midAutumn, 'CN'),
  // ⚠ No 端午节 2026 — it fell on 19 June, already past. The seed only ever
  // carries occasions still ahead of it, same as the rest of this 2026 block.
  ('国庆节 National Day', DateTime(2026, 10, 1), OccasionTag.guoqing, 'CN'),
  ('Deepavali', DateTime(2026, 11, 8), OccasionTag.deepavali, 'MY'),
  ('Christmas', DateTime(2026, 12, 25), OccasionTag.christmas, 'INTL'),
  // ── 2027 ──
  ('New Year', DateTime(2027, 1, 1), OccasionTag.newYear, 'INTL'),
  ('春节 Chinese New Year', DateTime(2027, 2, 6), OccasionTag.cny, 'CN'),
  ('Lebaran / Aidilfitri', DateTime(2027, 3, 9), OccasionTag.lebaran, 'ID/MY'),
  ('Idul Adha', DateTime(2027, 5, 16), OccasionTag.idulAdha, 'ID/MY'),
  ('端午节 Dragon Boat', DateTime(2027, 6, 9), OccasionTag.duanwu, 'CN'),
  ('中秋节 Mid-Autumn', DateTime(2027, 9, 15), OccasionTag.midAutumn, 'CN'),
  ('国庆节 National Day', DateTime(2027, 10, 1), OccasionTag.guoqing, 'CN'),
  ('Deepavali', DateTime(2027, 10, 29), OccasionTag.deepavali, 'MY'),
  ('Christmas', DateTime(2027, 12, 25), OccasionTag.christmas, 'INTL'),
  // ── 2028 ──
  ('New Year', DateTime(2028, 1, 1), OccasionTag.newYear, 'INTL'),
  ('春节 Chinese New Year', DateTime(2028, 1, 26), OccasionTag.cny, 'CN'),
  ('Lebaran / Aidilfitri', DateTime(2028, 2, 26), OccasionTag.lebaran, 'ID/MY'),
  ('Idul Adha', DateTime(2028, 5, 5), OccasionTag.idulAdha, 'ID/MY'),
  ('端午节 Dragon Boat', DateTime(2028, 5, 28), OccasionTag.duanwu, 'CN'),
  ('中秋节 Mid-Autumn', DateTime(2028, 10, 3), OccasionTag.midAutumn, 'CN'),
  ('国庆节 National Day', DateTime(2028, 10, 1), OccasionTag.guoqing, 'CN'),
  ('Deepavali', DateTime(2028, 11, 15), OccasionTag.deepavali, 'MY'),
  ('Christmas', DateTime(2028, 12, 25), OccasionTag.christmas, 'INTL'),
  // ── 2029, so the runway warning stays quiet for a full two years ──
  ('New Year', DateTime(2029, 1, 1), OccasionTag.newYear, 'INTL'),
  ('春节 Chinese New Year', DateTime(2029, 2, 13), OccasionTag.cny, 'CN'),
];
