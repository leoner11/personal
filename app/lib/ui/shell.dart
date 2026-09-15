import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../data/database.dart';
import 'add_person_sheet.dart';
import '../domain/config.dart';
import '../domain/money_fmt.dart';
import '../domain/auth.dart';
import '../domain/sync.dart';
import 'account_dialog.dart';
import 'platform.dart';
import '../theme/tokens.dart';
import 'screens/calendar_screen.dart';
import 'screens/money_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/occasions_screen.dart';
import 'screens/people_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/today_screen.dart';
import 'widgets/app_icon.dart';
import 'widgets/primitives.dart';

enum Section {
  today('Today', Ic.today),
  calendar('Calendar', Ic.calendar),
  tasks('Tasks', Ic.tasks),
  occasions('Occasions', Ic.occasions),
  people('People', Ic.people),
  projects('Projects', Ic.projects),
  money('Money', Ic.money),
  notes('Notes', Ic.notes);

  const Section(this.label, this.icon);
  final String label;
  final Ic icon;
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.db});
  final AppDatabase db;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Section _section = Section.today;
  int _todayCount = 0;

  void _go(Section s) => setState(() => _section = s);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return CallbackShortcuts(
      bindings: {
        for (final (i, s) in Section.values.indexed)
          cmd(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i)): () =>
              _go(s),
        // Add person from anywhere — the most-used action in the app.
        cmd(LogicalKeyboardKey.keyN): () =>
            AddPersonSheet.show(context, widget.db),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: t.canvas,
          body: Row(
            children: [
              _Sidebar(
                current: _section,
                onSelect: _go,
                todayCount: _todayCount,
                db: widget.db,
              ),
              Expanded(
                child: switch (_section) {
                  Section.today => TodayScreen(
                      db: widget.db,
                      onCount: (n) => WidgetsBinding.instance
                          .addPostFrameCallback((_) {
                        if (mounted && n != _todayCount) {
                          setState(() => _todayCount = n);
                        }
                      }),
                      onGo: _go,
                    ),
                  Section.calendar => CalendarScreen(db: widget.db),
                  Section.tasks => TasksScreen(db: widget.db),
                  Section.occasions => OccasionsScreen(db: widget.db),
                  Section.people => PeopleScreen(db: widget.db),
                  Section.projects => ProjectsScreen(db: widget.db),
                  Section.money => MoneyScreen(db: widget.db),
                  Section.notes => NotesScreen(db: widget.db),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.current,
    required this.onSelect,
    required this.todayCount,
    required this.db,
  });

  final Section current;
  final ValueChanged<Section> onSelect;
  final int todayCount;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: t.sidebar,
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // On the Mac, content extends under the hidden titlebar.
          SizedBox(height: titlebarInset),
          const _Brand(),
          for (final s in Section.values)
            _NavItem(
              section: s,
              active: s == current,
              // Count badge only for Today. A permanent badge on People
              // showing 200 is noise, not information.
              badge: s == Section.today && todayCount > 0 ? todayCount : null,
              onTap: () => onSelect(s),
            ),
          const Spacer(),
          _Footer(db: db),
        ],
      ),
    );
  }
}

/// Mark plus wordmark. The wordmark asset is coverage only, tinted here, so
/// it follows the text colour into dark mode instead of staying black.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 10, 14),
      child: Row(
        children: [
          const Image(
            image: AssetImage('assets/brand/sidebar_mark.png'),
            width: 28,
            height: 28,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 8),
          Image(
            image: const AssetImage('assets/brand/sidebar_wordmark.png'),
            height: 15,
            color: t.textPrimary,
            colorBlendMode: BlendMode.srcIn,
            filterQuality: FilterQuality.medium,
            semanticLabel: 'Personal',
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem(
      {required this.section,
      required this.active,
      required this.onTap,
      this.badge});
  final Section section;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final active = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: D.sidebarItem,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: active
                ? t.accentWash
                : _hover
                    ? t.subtle
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(D.radiusControl),
            border: active
                ? Border(left: BorderSide(color: t.accent, width: 2))
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              AppIcon(widget.section.icon,
                  scale: IconScale.nav,
                  color: active ? t.accent : t.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.section.label,
                    style: T.body.copyWith(
                      color: active ? t.textPrimary : t.textSecondary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    )),
              ),
              if (widget.badge != null)
                StatusTag(tone: t.attention, label: '${widget.badge}'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sync state and calendar runway. Never a spinner, never a dialog.
/// ⚠ The runway line makes the app's one silent failure visible.
/// ⚠ Never a spinner, never a dialog. Turns to attention only after a
/// failure older than an hour.
class _SyncLine extends StatefulWidget {
  const _SyncLine({required this.db});
  final AppDatabase db;

  @override
  State<_SyncLine> createState() => _SyncLineState();
}

class _SyncLineState extends State<_SyncLine> {
  String _label = 'Local only';
  bool _stale = false;

  AuthState? get _auth => appAuth;

  /// ⚠ Sync needs BOTH a configured https server and a signed-in account. The
  /// token is no longer compiled in, so "configured" alone is not enough.
  bool get _canSync => kSyncEnabled && (_auth?.signedIn ?? false);

  @override
  void initState() {
    super.initState();
    _auth?.addListener(_onAuth);
    if (_canSync) _run();
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() {
    if (!mounted) return;
    setState(() {});
    if (_canSync) _run();
  }

  Future<void> _open() async {
    await AccountDialog.show(context);
  }

  Future<void> _run() async {
    final token = _auth?.token;
    if (token == null) return;
    final engine =
        SyncEngine(widget.db, baseUrl: kSyncBaseUrl, token: token);
    final at = await engine.run();
    // ⚠ A 401 is not a transient failure to retry forever. The token was
    // revoked or the account changed, and only signing in again fixes it —
    // so drop it rather than sitting on "Syncing…" against a server that
    // will never accept us.
    if (engine.unauthorized) {
      await _auth?.forgetRejectedToken();
      if (!mounted) return;
      setState(() {
        _label = 'Sign in again';
        _stale = true;
      });
      return;
    }
    if (!mounted) return;
    if (at != null) {
      setState(() {
        _label = 'Synced ${fmtAgo(at)}';
        _stale = false;
      });
    } else {
      final last = await engine.lastSynced();
      if (!mounted) return;
      setState(() {
        _label = last == null ? 'Never synced' : 'Synced ${fmtAgo(last)}';
        _stale = last == null ||
            DateTime.now().difference(last) > const Duration(hours: 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final signedOut = kSyncEnabled && !(_auth?.signedIn ?? false);
    final label = signedOut ? 'Sign in to sync' : _label;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // ⚠ Always tappable now. When it says "Local only" the useful action
        // is opening the account panel, not retrying a sync that cannot run.
        onTap: _canSync ? _run : _open,
        onSecondaryTap: _open,
        child: Text(label,
            style: T.micro.copyWith(
                color: (_stale || signedOut)
                    ? t.attention.text
                    : t.textMuted)),
      ),
    );
  }
}

class _Footer extends StatefulWidget {
  const _Footer({required this.db});
  final AppDatabase db;

  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  // Held in state — an inline future re-queries on every shell rebuild.
  late final Future<DateTime?> _runway = widget.db.calendarRunway();

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SyncLine(db: db),
          const SizedBox(height: 3),
          // ⚠ Always visible, costs nothing, makes the invisible state
          // visible. Amber only once the runway is genuinely short — a
          // permanently amber line is one you stop reading.
          FutureBuilder<DateTime?>(
            future: _runway,
            builder: (context, snap) {
              final end = snap.data;
              if (end == null) {
                return Text('Calendar empty',
                    style: T.micro.copyWith(color: t.attention.text));
              }
              final short = end.difference(DateTime.now()).inDays < 365;
              return Text('Calendar → ${end.year}',
                  style: T.micro.copyWith(
                      color: short ? t.attention.text : t.textMuted));
            },
          ),
        ],
      ),
    );
  }
}

/// Standard screen scaffold: title, optional trailing action, canvas ground.
class ScreenBody extends StatelessWidget {
  const ScreenBody(
      {super.key, required this.title, required this.child, this.trailing, this.subtitle});
  final String title;
  final Widget child;
  final Widget? trailing;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      color: t.canvas,
      child: Stack(
        children: [
          // ⚠ Only the header moves the window. DragToMoveArea is a
          // GestureDetector with onPanStart + onDoubleTap, and it used to wrap
          // this whole screen — so every text field underneath lost
          // drag-to-select and double-click-to-select-a-word to the window
          // manager. The strip below the native titlebar and the title block
          // itself are draggable; nothing else is.
          // Windows has its own titlebar to drag, so no strip there.
          if (isMac)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 34,
              child: DragToMoveArea(child: SizedBox.expand()),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, titlebarInset - 4, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expanded, not Spacer: the empty space beside the title
                    // stays a drag handle, but the trailing action sits
                    // outside the drag area so its taps arrive intact.
                    Expanded(
                      child: DragToMoveArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: T.screenTitle
                                    .copyWith(color: t.textPrimary)),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              subtitle!,
                            ],
                          ],
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: child,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
