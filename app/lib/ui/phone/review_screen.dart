import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/auth.dart';
import '../../domain/config.dart';
import '../../domain/money_fmt.dart';
import '../../domain/money_totals.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'account_screen.dart';
import 'money_screen.dart';
import 'notes_screen.dart';
import 'occasion_tag_sheets.dart';
import 'phone_primitives.dart';
import 'projects_screen.dart';
import 'tasks_list_screen.dart';

/// The fifth tab. Money, Tasks, Projects and Notes live behind it — and now
/// Calendar has taken the fourth slot, this is the last stop of the bar.
///
/// ⚠ WHY A HUB AND NOT THREE MORE TABS. Six tabs at 390pt is 65pt each, which
/// truncates the labels and breaks the 3–5 the platform expects. Six was the
/// only alternative that kept everything one tap away, and it bought that by
/// making all six harder to hit.
///
/// ⚠ AND WHY THIS IS NOT THE DRAWER THE DESIGN SPEC BANS. A drawer hides its
/// destinations behind an icon and off-screen. These three are on screen, in a
/// list, with their counts — the tab is a destination, not a gesture.
///
/// v2: the rows carry the same leading glyphs the desktop sidebar gives the
/// same destinations (`Section.money → wallet`, `projects → folderOpen`,
/// `notes → fileText`). The tab bar has made icons the shell's destination
/// language; text-only rows under an all-icon tab bar were the mismatch.
/// Account stays glyph-less below the divider: it is a status surface, not a
/// destination, and a glyph for it would invent a second new `Ic` entry
/// beyond `archive`.
class PhoneReviewScreen extends StatelessWidget {
  const PhoneReviewScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return PhoneScaffold(
      title: 'Review',
      child: RefreshIndicator(
        color: AppTokens.of(context).accent,
        backgroundColor: AppTokens.of(context).card,
        // ⚠ The pulse is a real sync round-trip, not theatre (§3.4): local
        // queries answer in under a frame, so refreshing them would fake a
        // reload. The counts and balances below ride their streams and pick
        // up whatever the round-trip writes — the line runSyncPulse returns
        // is Money's grammar; the hub stays wordless (P4).
        onRefresh: () async {
          await runSyncPulse(db);
        },
        child: ListView(
          // Short lists must still pull.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            PD.screenPad,
            0,
            PD.screenPad,
            PD.sectionGap,
          ),
          children: [
            _MoneyEntry(db: db),
            const PhoneDivider(),
            // Tasks are a first-class destination too (session 2): the Today
            // quick-add stays, but on a day the deck is empty the list must
            // still be reachable without knowing a task exists to tap.
            _CountEntry(
              icon: Ic.tasks,
              title: 'Tasks',
              // The subtitle counts OPEN tasks: that is the number that
              // decides whether to tap. Done tasks are history — the hub is
              // maintenance, not an archive.
              stream: db
                  .watchTasks()
                  .map((l) => l.where((t) => t.doneAt == null).toList()),
              label: (n) => n == 1 ? '1 task' : '$n tasks',
              onTap: (c) => _push(c, PhoneTasksScreen(db: db)),
            ),
            const PhoneDivider(),
            _CountEntry(
              icon: Ic.projects,
              title: 'Projects',
              stream: db.watchEngagements(),
              // Free text, so "open" cannot be counted — the count is the list
              // length and nothing more is claimed.
              label: (n) => n == 1 ? '1 project' : '$n projects',
              onTap: (c) => _push(c, PhoneProjectsScreen(db: db)),
            ),
            const PhoneDivider(),
            _CountEntry(
              icon: Ic.notes,
              title: 'Notes',
              stream: db.watchNotes(),
              label: (n) => n == 1 ? '1 note' : '$n notes',
              onTap: (c) => _push(c, PhoneNotesScreen(db: db)),
            ),
            const PhoneDivider(),
            // ⚠ The vocabulary, not a list of festivals. Sits in the hub
            // because it is maintenance you do once and then forget — the
            // '+' chip in capture covers the case where you need one NOW.
            _CountEntry(
              icon: Ic.occasions,
              title: 'Occasion tags',
              stream: db.watchOccasionTags(),
              label: (n) => n == 1 ? '1 tag' : '$n tags',
              onTap: (c) => _push(c, PhoneOccasionTagsScreen(db: db)),
            ),
            // The group break before Account — it is a different sort of row.
            const SizedBox(height: PD.sectionGap),
            _AccountEntry(),
            const PhoneDivider(),
          ],
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // ⚠ Scaffold, not bare: these screens are pushed over the shell and so
        // have no Scaffold of their own, and the back gesture is the system one.
        //
        // ⚠ And SafeArea(bottom) specifically. On the tab screens the bottom
        // bar holds content clear of the system navigation bar; a pushed
        // screen has no bottom bar, so without this the last ledger row sits
        // underneath it.
        builder: (c) => Scaffold(
          backgroundColor: AppTokens.of(c).canvas,
          body: SafeArea(top: false, child: screen),
        ),
      ),
    );
  }
}

/// ⚠ Sign-in lives here, one tap from a tab, and NOT in front of the app.
/// Local-first is the non-negotiable: everything works signed out, and this
/// row decides only whether the local database also reaches the server.
class _AccountEntry extends StatelessWidget {
  const _AccountEntry();

  @override
  Widget build(BuildContext context) {
    final auth = appAuth;
    if (auth == null) {
      // Production sets appAuth before the first frame; tests run without it.
      // The row still renders — the hub always renders its rows (§4).
      return const PhoneRow(
        title: 'Account',
        subtitle: 'Not signed in — this phone is local only',
      );
    }
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return PhoneRow(
          title: 'Account',
          subtitle: !kSyncEnabled
              ? 'No server configured'
              : auth.signedIn
              ? 'Syncing as ${auth.username}'
              : 'Not signed in — this phone is local only',
          chevron: true,
          onTap: () => PhoneReviewScreen._push(
            context,
            PhoneAccountScreen(auth: auth),
          ),
        );
      },
    );
  }
}

/// Money gets the balance, not a row count. The whole point of the screen is
/// one number seen often, and making it visible a tap earlier is free.
class _MoneyEntry extends StatelessWidget {
  const _MoneyEntry({required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return StreamBuilder<List<MoneyRow>>(
      stream: db.watchMoney(),
      builder: (context, snap) {
        final rows = snap.data ?? const <MoneyRow>[];
        final balances = MoneyTotals.of(rows).balances;
        return PhoneRow(
          title: 'Money',
          subtitle: balances.isEmpty
              ? 'Nothing recorded'
              // `CNY 12,400.00`, not a bare ¥ figure — the currency is the
              // information here; currencies are never converted (§8).
              : balances.entries
                    .map((e) => '${e.key} ${fmtMoney(e.value, e.key, symbol: false)}')
                    .join(' · '),
          chevron: true,
          leading: AppIcon(Ic.money, size: 22, color: t.textSecondary),
          onTap: () => PhoneReviewScreen._push(context, PhoneMoneyScreen(db: db)),
        );
      },
    );
  }
}

class _CountEntry<R> extends StatelessWidget {
  const _CountEntry({
    required this.icon,
    required this.title,
    required this.stream,
    required this.label,
    required this.onTap,
  });
  final Ic icon;
  final String title;
  final Stream<List<R>> stream;
  final String Function(int n) label;
  final void Function(BuildContext c) onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return StreamBuilder<List<R>>(
      stream: stream,
      builder: (context, snap) {
        final n = (snap.data ?? const []).length;
        return PhoneRow(
          title: title,
          subtitle: label(n),
          chevron: true,
          leading: AppIcon(icon, size: 22, color: t.textSecondary),
          onTap: () => onTap(context),
        );
      },
    );
  }
}
