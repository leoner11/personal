import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'data/database.dart';
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

  runApp(App(db: db));
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
      title: 'Personal CRM',
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    ),
    () async => windowManager.show(),
  );
}

class App extends StatelessWidget {
  const App({super.key, required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Personal CRM',
        debugShowCheckedModeBanner: false,
        // Follows the system. No in-app toggle.
        themeMode: ThemeMode.system,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        // ⚠ Two shells, one codebase. The desktop three-pane layout does not
        // survive a 390pt screen, and a responsive breakpoint between them
        // would mean the density table, the keyboard map and every hover
        // action had to work at both ends. They do not.
        home: isDesktop ? Shell(db: db) : PhoneShell(db: db),
      );
}
