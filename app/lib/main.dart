import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'data/database.dart';
import 'domain/auth.dart';
import 'domain/notifications.dart';
import 'theme/tokens.dart';
import 'ui/phone/phone_shell.dart';
import 'ui/shell.dart';

/// ⚠ window_manager is desktop-only. Calling ensureInitialized() on a phone
/// throws before the first frame, so every entry point below it has to sit
/// outside the guard — the database, the seed and the notifier are shared.
bool get isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktop) await _setUpWindow();
  final db = AppDatabase();

  // Seed three years of occasions on first launch, then rebuild every pending
  // notification from scratch. ⚠ Both are load-bearing: an empty calendar and
  // a wiped schedule look identical to a normal quiet day.
  await seedIfEmpty(db);
  final notifier = Notifier(db);
  await notifier.init();
  await notifier.rescheduleAll();
  appNotifier = notifier;

  // ⚠ Loaded BEFORE the first frame so the UI never flashes "signed out" at
  // someone who is signed in — the Keychain read is async and a frame is not.
  // Note this does not gate anything: the app runs identically either way.
  final auth = AuthState();
  await auth.load();
  appAuth = auth;

  // ⚠ Read BEFORE the first frame. If the app was launched by tapping a
  // reminder, the first screen must be Today — asking afterwards means the
  // user watches it jump.
  final fromNotification = await notifier.launchedFromNotification();

  runApp(App(db: db, openOnToday: fromNotification));
}

Future<void> _setUpWindow() async {
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      // 200 sidebar + 300 list + 420 detail minimum = 920 of content.
      // The old 720 minimum squeezed the detail pane below its own spec and
      // made fixed-width control rows overflow.
      size: Size(1180, 760),
      minimumSize: Size(960, 600),
      title: 'Personal',
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    ),
    () async => windowManager.show(),
  );
}

class App extends StatefulWidget {
  const App({
    super.key,
    required this.db,
    this.onPause,
    this.openOnToday = false,
  });
  final AppDatabase db;

  /// True when this launch was started by tapping a notification. Phone only —
  /// the desktop shell has no tabs to open onto.
  final bool openOnToday;

  /// Seam for the test that this hook exists at all. Production leaves it
  /// null and the module-level [appNotifier] is used.
  final Future<void> Function()? onPause;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  /// ⚠ THE SCHEDULE IS REBUILT WHEN THE APP LEAVES THE FOREGROUND, not only at
  /// launch. Without this, a person captured during a session gets no
  /// notifications until the app is next opened — and the phone's entire
  /// interaction model is "capture in 10 seconds and close". Someone captured
  /// 15 days before a festival, with the app never reopened, would silently
  /// get nothing. That is the app's whole purpose failing quietly.
  ///
  /// One hook, so it catches every write in the session and cannot be
  /// forgotten the way four post-write call sites could be.
  ///
  /// ⚠ NEVER await this on the capture path. It cancels and re-adds ~18
  /// alarms, and the 10-second budget owns that screen. Here it is free: the
  /// user has already left.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onPause: _rescheduleInBackground);
  }

  void _rescheduleInBackground() {
    final reschedule = widget.onPause ?? appNotifier?.rescheduleAll;
    if (reschedule != null) unawaited(reschedule());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Personal',
        debugShowCheckedModeBanner: false,
        // Follows the system. No in-app toggle.
        themeMode: ThemeMode.system,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        // ⚠ Two shells, one codebase. The desktop three-pane layout does not
        // survive a 390pt screen, and a responsive breakpoint between them
        // would mean the density table, the keyboard map and every hover
        // action had to work at both ends. They do not.
        home: isDesktop
            ? Shell(db: widget.db)
            : PhoneShell(
                db: widget.db,
                initial:
                    widget.openOnToday ? PhoneTab.today : PhoneTab.capture,
              ),
      );
}
