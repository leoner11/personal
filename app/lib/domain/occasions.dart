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
