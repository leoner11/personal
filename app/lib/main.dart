import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'data/database.dart';
import 'domain/notifications.dart';
import 'theme/tokens.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(900, 620),
      minimumSize: Size(720, 480),
      title: 'Personal CRM',
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    ),
    () async => windowManager.show(),
  );
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
        home: Shell(db: db),
      );
}
