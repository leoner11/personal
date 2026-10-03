import 'dart:async' show Timer, unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'data/database.dart';
import 'domain/auth.dart';
import 'domain/notifications.dart';
import 'domain/tag_vocab.dart';
import 'theme/tokens.dart';
import 'ui/phone/money_screen.dart';
import 'ui/phone/notes_screen.dart';
import 'ui/phone/calendar_screen.dart';
import 'ui/phone/occasion_tag_sheets.dart';
import 'ui/phone/phone_primitives.dart' show PhoneKeyboardDismisser;
import 'ui/phone/phone_shell.dart';
import 'ui/phone/projects_screen.dart';
import 'ui/phone/tasks_list_screen.dart';
import 'ui/shell.dart';

/// ⚠ window_manager is desktop-only. Calling ensureInitialized() on a phone
/// throws before the first frame, so every entry point below it has to sit
/// outside the guard — the database, the seed and the notifier are shared.
bool get isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ⚠ NEVER A BLANK SCREEN. Everything below runs before the first frame, so
  // an error in it used to leave a white screen with nothing to read — which
  // is exactly what the phone showed on 24 Sep. Now it says what failed.
  // A step that never returns is as blank as one that throws, so a slow
  // start also says which step it is waiting on.
  var started = false;
  final watchdog = Timer(const Duration(seconds: 15), () {
    if (!started) {
      runApp(_StartupError(
          error: 'Still starting after 15s, waiting on: $_startStep',
          stack: StackTrace.empty));
    }
  });
  try {
    await _start();
    started = true;
  } catch (e, st) {
    started = true;
    runApp(_StartupError(error: 'Failed at: $_startStep\n$e', stack: st));
  } finally {
    watchdog.cancel();
  }
}

/// The startup step in progress, named in the error screen.
String _startStep = 'begin';

Future<void> _start() async {
  if (isDesktop) await _setUpWindow();
  _startStep = 'open database';
  final db = AppDatabase();

  // Seed three years of occasions on first launch, then rebuild every pending
  // notification from scratch. ⚠ Both are load-bearing: an empty calendar and
  // a wiped schedule look identical to a normal quiet day.
  // ⚠ TAGS BEFORE OCCASIONS. backfillSeedOccasions now refuses to seed dates
  // for a tag that is not in the table, so seeding the vocabulary second would
  // skip every festival on a virgin database and leave it permanently empty.
  _startStep = 'seed tags (first database read)';
  await seedBuiltInTags(db);
  // ⚠ Bound before the first frame: chips and person rows resolve slugs to
  // labels out of this, and an unbound vocabulary draws every tag as its raw
  // slug until the first rebuild.
  TagVocab.bind(db);
  _startStep = 'seed occasions';
  await seedIfEmpty(db);
  // ⚠ And top up anything added to the seed since this database was created.
  // Without it a new occasion tag is visible on the capture screen while the
  // calendar behind it stays empty, and nothing ever fires.
  await backfillSeedOccasions(db);
  _startStep = 'notifications';
  final notifier = Notifier(db);
  await notifier.init();
  await notifier.rescheduleAll();
  appNotifier = notifier;

  // ⚠ Loaded BEFORE the first frame so the UI never flashes "signed out" at
  // someone who is signed in — the Keychain read is async and a frame is not.
  // Note this does not gate anything: the app runs identically either way.
  _startStep = 'sign-in state';
  final auth = AuthState();
  await auth.load();
  appAuth = auth;

  // ⚠ Read BEFORE the first frame. If the app was launched by tapping a
  // reminder, the first screen must be Today — asking afterwards means the
  // user watches it jump.
  _startStep = 'launch notification';
  final fromNotification = await notifier.launchedFromNotification();

  runApp(App(db: db, openOnToday: fromNotification));
}

/// What the app shows when it could not start. Plain on purpose: it must
/// render even if the theme or the database is what broke.
class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.stack});
  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                'Personal could not start.\n\n$error\n\n$stack',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
      );
}

Future<void> _setUpWindow() async {
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      // 200 sidebar + 300 list + 420 detail minimum = 920 of content.
      // The old 720 minimum squeezed the detail pane below its own spec and
      // made fixed-width control rows overflow.
      size: Size(1180, 760),
      minimumSize: Size(960, 600),
      title: 'Personal',
      // ⚠ Hidden on the Mac only. There the traffic lights survive; on
      // Windows a hidden titlebar takes minimise, maximise and close with it.
      titleBarStyle:
          Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
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
        // Above the Navigator, so it reaches pushed screens and sheets too.
        builder: isDesktop
            ? null
            : (context, child) => PhoneKeyboardDismisser(child: child!),
        home: isDesktop
            ? Shell(db: widget.db)
            : _phoneHome(context),
      );

  /// ⚠ DEBUG HARNESS for unattended simulator screenshots — `simctl` cannot
  /// tap, so a screenshot pass can neither pick a start tab nor reach a
  /// pushed screen. `flutter run --dart-define=UI_SCREEN=today` (or people /
  /// calendar / review / money / notes / projects / tasks / tags / meeting)
  /// opens that
  /// directly. ANY OTHER VALUE, OR NONE, IS PRODUCTION: the shell, Capture
  /// default, notification routing untouched. Tests never set the define.
  Widget _phoneHome(BuildContext context) {
    final db = widget.db;
    switch (const String.fromEnvironment('UI_SCREEN')) {
      case 'today':
        return PhoneShell(db: db, initial: PhoneTab.today);
      case 'people':
        return PhoneShell(db: db, initial: PhoneTab.people);
      case 'calendar':
        return PhoneShell(db: db, initial: PhoneTab.calendar);
      case 'review':
        return PhoneShell(db: db, initial: PhoneTab.review);
      case 'money':
      case 'notes':
      case 'projects':
      case 'tasks':
      case 'tags':
        final screen = switch (const String.fromEnvironment('UI_SCREEN')) {
          'money' => PhoneMoneyScreen(db: db),
          'notes' => PhoneNotesScreen(db: db),
          'projects' => PhoneProjectsScreen(db: db),
          'tags' => PhoneOccasionTagsScreen(db: db),
          _ => PhoneTasksScreen(db: db),
        };
        // The same wrap a Review push gets (see PhoneReviewScreen._push).
        // ⚠ Builder, not the bare context: _phoneHome runs ABOVE the
        // MaterialApp, where the token extension does not exist yet.
        return Builder(
          builder: (context) => Scaffold(
            backgroundColor: AppTokens.of(context).canvas,
            body: SafeArea(top: false, child: screen),
          ),
        );
      case 'meeting':
        // The meeting sheet, rendered as a page so a screenshot pass can see
        // it — simctl cannot tap, so the sheet is otherwise unreachable
        // unattended. First meeting wins; none means the New sheet.
        return FutureBuilder<Meeting?>(
          future: db.allMeetings().then((r) => r.isEmpty ? null : r.first),
          // ⚠ Nothing until the future lands. Building the sheet first and
          // letting it rebuild reuses the same State, so initState already
          // ran with existing == null and the sheet never picks the row up.
          builder: (context, snap) => snap.connectionState !=
                  ConnectionState.done
              ? const SizedBox.shrink()
              : Builder(
                  builder: (context) => Scaffold(
                    backgroundColor: AppTokens.of(context).canvas,
                    body: SafeArea(
                        top: false,
                        child:
                            PhoneMeetingSheet(db: db, existing: snap.data)),
                  ),
                ),
        );
      case 'note':
        // The editor is pushed, so it needs a Note row — first one wins.
        return FutureBuilder<Note?>(
          future: db.watchNotes().first.then(
                (rows) => rows.isEmpty ? null : rows.first,
              ),
          builder: (context, snap) => snap.hasData && snap.data != null
              ? PhoneNoteEditor(db: db, note: snap.data!)
              : const SizedBox.shrink(),
        );
    }
    return PhoneShell(
      db: db,
      initial: widget.openOnToday ? PhoneTab.today : PhoneTab.capture,
    );
  }
}
