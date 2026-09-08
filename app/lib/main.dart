import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'data/database.dart';
import 'theme/tokens.dart';
import 'ui/people_screen.dart';

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
  runApp(App(db: AppDatabase()));
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
        home: DragToMoveArea(child: PeopleScreen(db: db)),
      );
}
