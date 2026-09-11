import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/notifications.dart';
import '../../theme/tokens.dart';
import 'capture_screen.dart';
import 'people_screen.dart';
import 'today_screen.dart';

enum PhoneTab { capture, today, people }

/// Three tabs, bottom bar. No drawer, no hamburger, no nested tab stacks, and
/// nothing more than one push deep from its tab. Back is the system gesture.
///
/// ⚠ CAPTURE IS THE DEFAULT TAB, NOT TODAY. The app's stated failure mode is
/// that capture stops happening by week three; landing on the capture screen is
/// the cheapest possible intervention against it, and the flowchart already
/// asks for "one tap from app home".
///
/// ⚠ The exception: a notification tap must route straight to Today. B1 → B2
/// is a two-step loop and it has to stay two steps. See [openTo].
///
/// Both directions of that tap are covered, and they are different mechanisms:
///   - **Cold launch** — the process did not exist when the tap happened, so
///     `main()` asks the plugin after the fact and passes [initial].
///   - **Warm tap** — the app was already running, so the plugin's response
///     callback bumps [notificationTaps] and the listener below reacts.
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
                  (PhoneTab.capture, 'Capture', Icons.add_circle_outline),
                  (PhoneTab.today, 'Today', Icons.wb_sunny_outlined),
                  (PhoneTab.people, 'People', Icons.people_outline),
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = tab),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon,
                              size: 22,
                              color: _tab == tab ? t.accent : t.textMuted),
                          const SizedBox(height: 2),
                          Text(label,
                              style: PT.micro.copyWith(
                                  color: _tab == tab ? t.accent : t.textMuted,
                                  fontWeight: _tab == tab
                                      ? FontWeight.w600
                                      : FontWeight.w500)),
                        ],
                      ),
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
