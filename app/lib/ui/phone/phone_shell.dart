import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/notifications.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'calendar_screen.dart';
import 'capture_screen.dart';
import 'people_screen.dart';
import 'phone_primitives.dart';
import 'review_screen.dart';
import 'today_screen.dart';

enum PhoneTab { capture, today, people, calendar, review }

/// The Today tab's queue count, surfaced as the ONLY badge in the shell
/// (§3.1 — "a permanent badge on People showing 200 is noise, not
/// information", the desktop sidebar rule ported). [PhoneTodayScreen] writes
/// it every time it (re)loads [loadToday]; the shell only listens. No extra
/// queries, and the badge is always what Today itself sees.
final ValueNotifier<int> phoneTodayCount = ValueNotifier<int>(0);

/// Five tabs, bottom bar — the platform ceiling. Six at 390pt is 65pt each:
/// truncated labels, past the 3–5 the platform expects. No drawer, no nested
/// tab stacks, nothing more than one push deep from its tab. Back is the
/// system gesture.
///
/// ⚠ CAPTURE IS THE DEFAULT TAB, NOT TODAY. The app's stated failure mode is
/// that capture stops happening by week three; landing on the capture screen
/// is the cheapest possible intervention against it, and the flowchart already
/// asks for "one tap from app home".
///
/// ⚠ The exception: a notification tap must route straight to Today. B1 → B2
/// is a two-step loop and it has to stay two steps. See [openTo]. Both
/// directions of that tap are covered, and they are different mechanisms:
///   - **Cold launch** — the process did not exist when the tap happened, so
///     `main()` asks the plugin after the fact and passes [initial].
///   - **Warm tap** — the app was already running, so the plugin's response
///     callback bumps [notificationTaps] and the listener below reacts.
///
/// v2: Calendar is the fifth tab (§2 — it absorbs the occasions browse the
/// phone IA never had), and the tab bar moved to house icons via [Ic]. Every
/// Material glyph died with the migration; `lucide` is the only icon source
/// in the app, same rule the desktop enforces.
class PhoneShell extends StatefulWidget {
  const PhoneShell({super.key, required this.db, this.initial = PhoneTab.capture});
  final AppDatabase db;
  final PhoneTab initial;

  @override
  State<PhoneShell> createState() => PhoneShellState();
}

class PhoneShellState extends State<PhoneShell> {
  late PhoneTab _tab = widget.initial;

  /// Entry point for a notification tap.
  void openTo(PhoneTab tab) => setState(() => _tab = tab);

  @override
  void initState() {
    super.initState();
    notificationTaps.addListener(_onNotificationTap);
  }

  @override
  void dispose() {
    notificationTaps.removeListener(_onNotificationTap);
    super.dispose();
  }

  /// ⚠ The tap has to win over wherever the app was left. Someone who taps a
  /// 中秋节 reminder and lands on a half-typed capture form has been given the
  /// wrong screen at the one moment the app had their attention.
  void _onNotificationTap() => openTo(PhoneTab.today);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.canvas,
      // ⚠ resizeToAvoidBottomInset stays true: the capture form must scroll
      // clear of the keyboard, since the keyboard is up the whole time it is
      // being used.
      body: IndexedStack(
        index: _tab.index,
        children: [
          CaptureScreen(db: widget.db),
          PhoneTodayScreen(db: widget.db),
          PhonePeopleScreen(db: widget.db),
          PhoneCalendarScreen(db: widget.db),
          PhoneReviewScreen(db: widget.db),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: t.sidebar,
          border: Border(top: BorderSide(color: t.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            // The platform default, never a custom height.
            height: 56,
            child: Row(
              children: [
                for (final (tab, label, icon) in const [
                  (PhoneTab.capture, 'Capture', Ic.add),
                  (PhoneTab.today, 'Today', Ic.today),
                  (PhoneTab.people, 'People', Ic.people),
                  (PhoneTab.calendar, 'Calendar', Ic.calendar),
                  (PhoneTab.review, 'Review', Ic.archive),
                ])
                  Expanded(
                    child: _PhoneTabButton(
                      tab: tab,
                      label: label,
                      icon: icon,
                      selected: _tab == tab,
                      badge: tab == PhoneTab.today,
                      onTap: () => setState(() => _tab = tab),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab: house glyph at 22, micro label, accent when active. Presses
/// scale on the house spring (§3.6) — the bar answers too. The badge rides
/// only on Today and follows [phoneTodayCount].
class _PhoneTabButton extends StatelessWidget {
  const _PhoneTabButton({
    required this.tab,
    required this.label,
    required this.icon,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final PhoneTab tab;
  final String label;
  final Ic icon;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final color = selected ? t.accent : t.textMuted;
    return PhonePressable(
      onTap: onTap,
      pressedScale: 0.93,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            height: 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: AppIcon(icon, size: 22, color: color)),
                if (badge)
                  Positioned(
                    top: -3,
                    right: -6,
                    child: ValueListenableBuilder<int>(
                      valueListenable: phoneTodayCount,
                      builder: (context, count, _) {
                        // Mockup parity: every count change replays the
                        // spring pop (the chip's key-restart trick); hitting
                        // zero scales the badge away instead of cutting it.
                        final body = Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 15,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.attention.wash,
                            border: Border.all(
                                color: t.attention.dot, width: 0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ).copyWith(color: t.attention.text),
                          ),
                        );
                        return AnimatedScale(
                          scale: count > 0 ? 1 : 0,
                          duration:
                              const Duration(milliseconds: PM.clearMs),
                          curve: count > 0 ? PM.pop : Curves.ease,
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(count),
                            tween: Tween(begin: 0.92, end: 1),
                            duration: const Duration(milliseconds: 300),
                            curve: PM.pop,
                            builder: (context, s, child) =>
                                Transform.scale(scale: s, child: child),
                            child: body,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: PT.micro.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
        ],
      ),
    );
  }
}
