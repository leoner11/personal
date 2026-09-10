import 'package:flutter/material.dart';

/// One status tone: a dot, a wash, and text. Never guessed from a string —
/// each domain owns its own state -> tone map. See design system, Status tag.
@immutable
class Tone {
  const Tone({required this.dot, required this.wash, required this.text});
  final Color dot, wash, text;

  static Tone lerp(Tone a, Tone b, double t) => Tone(
        dot: Color.lerp(a.dot, b.dot, t)!,
        wash: Color.lerp(a.wash, b.wash, t)!,
        text: Color.lerp(a.text, b.text, t)!,
      );
}

/// Every colour in the app resolves through here. No widget hardcodes a hex.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.canvas,
    required this.card,
    required this.subtle,
    required this.sidebar,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.accentHover,
    required this.accentWash,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textInverse,
    required this.neutral,
    required this.info,
    required this.attention,
    required this.success,
    required this.danger,
  });

  final Color canvas, card, subtle, sidebar, line, lineStrong;
  final Color accent, accentHover, accentWash;
  final Color textPrimary, textSecondary, textMuted, textInverse;
  final Tone neutral, info, attention, success, danger;

  static const light = AppTokens(
    canvas: Color(0xFFF6F5F1),
    card: Color(0xFFFFFFFF),
    subtle: Color(0xFFEFEEE9),
    sidebar: Color(0xFFEDECE7),
    line: Color(0xFFE0DFD9),
    lineStrong: Color(0xFFCFCEC6),
    accent: Color(0xFF2F6B4F),
    accentHover: Color(0xFF245740),
    accentWash: Color(0xFFEAF2ED),
    textPrimary: Color(0xFF1B1F1D),
    textSecondary: Color(0xFF5A625D),
    textMuted: Color(0xFF8B938E),
    textInverse: Color(0xFFFFFFFF),
    neutral: Tone(dot: Color(0xFF9BA39D), wash: Color(0xFFF0F0EC), text: Color(0xFF5A625D)),
    info: Tone(dot: Color(0xFF3B82F6), wash: Color(0xFFEFF5FF), text: Color(0xFF2563EB)),
    attention: Tone(dot: Color(0xFFF59E0B), wash: Color(0xFFFDF6EC), text: Color(0xFFB45309)),
    success: Tone(dot: Color(0xFF22C55E), wash: Color(0xFFEFF8F1), text: Color(0xFF15803D)),
    danger: Tone(dot: Color(0xFFEF4444), wash: Color(0xFFFDF0EF), text: Color(0xFFB91C1C)),
  );

  /// ⚠ The accent INVERTS in dark mode. #2F6B4F on #222623 is 1.6:1 —
  /// effectively invisible. Text on a filled accent flips to ink.
  static const dark = AppTokens(
    canvas: Color(0xFF1A1D1B),
    card: Color(0xFF222623),
    subtle: Color(0xFF2A2F2C),
    sidebar: Color(0xFF171A18),
    line: Color(0xFF323834),
    lineStrong: Color(0xFF3E453F),
    accent: Color(0xFF7FC4A3),
    accentHover: Color(0xFF9BD4B8),
    accentWash: Color(0xFF233A2F),
    textPrimary: Color(0xFFECEFEC),
    textSecondary: Color(0xFFA2ACA6),
    textMuted: Color(0xFF767F79),
    textInverse: Color(0xFF12211A),
    neutral: Tone(dot: Color(0xFF9BA39D), wash: Color(0xFF2A2F2C), text: Color(0xFFA2ACA6)),
    info: Tone(dot: Color(0xFF3B82F6), wash: Color(0xFF1E2A3A), text: Color(0xFF7FADFF)),
    attention: Tone(dot: Color(0xFFF59E0B), wash: Color(0xFF33291A), text: Color(0xFFF0B265)),
    success: Tone(dot: Color(0xFF22C55E), wash: Color(0xFF1D3326), text: Color(0xFF6FD48F)),
    danger: Tone(dot: Color(0xFFEF4444), wash: Color(0xFF3A2220), text: Color(0xFFFF8A80)),
  );

  static AppTokens of(BuildContext c) => Theme.of(c).extension<AppTokens>()!;

  @override
  AppTokens copyWith({
    Color? canvas, Color? card, Color? subtle, Color? sidebar,
    Color? line, Color? lineStrong, Color? accent, Color? accentHover,
    Color? accentWash, Color? textPrimary, Color? textSecondary,
    Color? textMuted, Color? textInverse,
    Tone? neutral, Tone? info, Tone? attention, Tone? success, Tone? danger,
  }) =>
      AppTokens(
        canvas: canvas ?? this.canvas,
        card: card ?? this.card,
        subtle: subtle ?? this.subtle,
        sidebar: sidebar ?? this.sidebar,
        line: line ?? this.line,
        lineStrong: lineStrong ?? this.lineStrong,
        accent: accent ?? this.accent,
        accentHover: accentHover ?? this.accentHover,
        accentWash: accentWash ?? this.accentWash,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        textInverse: textInverse ?? this.textInverse,
        neutral: neutral ?? this.neutral,
        info: info ?? this.info,
        attention: attention ?? this.attention,
        success: success ?? this.success,
        danger: danger ?? this.danger,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentWash: Color.lerp(accentWash, other.accentWash, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      neutral: Tone.lerp(neutral, other.neutral, t),
      info: Tone.lerp(info, other.info, t),
      attention: Tone.lerp(attention, other.attention, t),
      success: Tone.lerp(success, other.success, t),
      danger: Tone.lerp(danger, other.danger, t),
    );
  }
}

/// macOS body text is 13pt, not 16px. Nothing above 20pt except the Money
/// balance figure. Uppercase is reserved for Micro.
abstract final class T {
  static const screenTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
  static const entityName = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  static const sectionLabel = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 13);
  static const secondary = TextStyle(fontSize: 11);
  static const micro = TextStyle(fontSize: 10, fontWeight: FontWeight.w500);
  static const mono = TextStyle(fontSize: 11, fontFamily: 'Menlo');
}

/// Phone type scale. ⚠ The 13pt body does NOT carry — the rule that produced
/// it was "match the platform's system UI size", and on iOS/Android that is
/// 17pt. Everything here holds the desktop ratios, scaled.
///
/// The screen title is the one place the phone is bigger than the Mac's 20pt
/// ceiling: a phone header has no window chrome to signal "new screen", so the
/// type has to do it alone.
abstract final class PT {
  static const screenTitle = TextStyle(fontSize: 28, fontWeight: FontWeight.w600);
  static const entityName = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
  static const sectionLabel = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 17);
  static const secondary = TextStyle(fontSize: 15);
  static const micro = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
  static const mono = TextStyle(fontSize: 15, fontFamily: 'Menlo');
}

/// Phone density. ⚠ Nothing interactive may be shorter than [tapMin].
abstract final class PD {
  static const listRow = 56.0;
  static const listRowTwoLine = 72.0;
  static const control = 48.0;
  static const groupHeader = 32.0;
  static const tag = 36.0;

  /// The floor for anything you can touch. No exceptions.
  static const tapMin = 44.0;

  /// Matches the Mac's ScreenBody horizontal padding, so the two shells feel
  /// like the same app rather than two ports.
  static const screenPad = 20.0;
  static const sectionGap = 16.0;
  static const groupGap = 12.0;
}

/// Design system density table. Flutter's defaults target touch and will
/// inflate every one of these.
abstract final class D {
  static const sidebarItem = 28.0;
  static const listRow = 32.0;
  static const listRowTwoLine = 44.0;
  static const tableRow = 28.0;
  static const timelineRow = 24.0;
  static const control = 28.0;
  static const tag = 18.0;
  static const groupHeader = 20.0;

  static const radiusPanel = 8.0;
  static const radiusControl = 6.0;
  static const radiusTag = 4.0;
}

ThemeData buildTheme(Brightness b) {
  final t = b == Brightness.dark ? AppTokens.dark : AppTokens.light;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    // Leave null so San Francisco resolves natively. Shipping Inter on a Mac
    // app is the tell that it was designed for the web first.
    fontFamily: null,
    visualDensity: VisualDensity.compact,
    scaffoldBackgroundColor: t.canvas,
    canvasColor: t.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: t.accent,
      brightness: b,
    ).copyWith(primary: t.accent, surface: t.card),
    extensions: [t],
    // Tabular figures everywhere, set once. Money columns that jitter as
    // digits change look broken.
    textTheme: Typography.material2021(platform: TargetPlatform.macOS)
        .black
        .apply(fontFamily: null)
        .merge(const TextTheme())
        .apply(
          bodyColor: t.textPrimary,
          displayColor: t.textPrimary,
          fontSizeFactor: 1.0,
        ),
  );
}

const kTabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
