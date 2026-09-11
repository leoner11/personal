import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/auth.dart';
import '../../domain/config.dart';
import '../../domain/money_fmt.dart';
import '../../domain/money_totals.dart';
import '../../theme/tokens.dart';
import 'account_screen.dart';
import 'money_screen.dart';
import 'notes_screen.dart';
import 'phone_primitives.dart';
import 'projects_screen.dart';

/// The fourth tab. Money, Projects and Notes live behind it.
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
/// These are the sit-down surfaces. Capture, Today and People stay in the bar
/// because they are what the phone is for; money review is something you do on
/// purpose, which is exactly what one extra tap is for.
class PhoneReviewScreen extends StatelessWidget {
  const PhoneReviewScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return PhoneBody(
      title: 'Review',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          PD.screenPad,
          0,
          PD.screenPad,
          PD.sectionGap,
        ),
        children: [
          _MoneyEntry(db: db),
          const PhoneDivider(),
          _CountEntry(
            title: 'Projects',
            stream: db.watchEngagements(),
            // Free text, so "open" cannot be counted — the count is the list
            // length and nothing more is claimed.
            label: (n) => n == 1 ? '1 project' : '$n projects',
            onTap: (c) => _push(c, PhoneProjectsScreen(db: db)),
          ),
          const PhoneDivider(),
          _CountEntry(
            title: 'Notes',
            stream: db.watchNotes(),
            label: (n) => n == 1 ? '1 note' : '$n notes',
            onTap: (c) => _push(c, PhoneNotesScreen(db: db)),
          ),
          const PhoneDivider(),
          const SizedBox(height: PD.sectionGap),
          _AccountEntry(db: db),
          const PhoneDivider(),
        ],
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
  const _AccountEntry({required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final auth = appAuth;
    if (auth == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => PhoneRow(
        title: 'Account',
        subtitle: !kSyncEnabled
            ? 'No server configured'
            : auth.signedIn
                ? 'Syncing as ${auth.username}'
                : 'Not signed in — this phone is local only',
        chevron: true,
        onTap: () => PhoneReviewScreen._push(
            context, PhoneAccountScreen(auth: auth)),
      ),
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
    return StreamBuilder<List<MoneyRow>>(
      stream: db.watchMoney(),
      builder: (context, snap) {
        final rows = snap.data ?? const <MoneyRow>[];
        final balances = MoneyTotals.of(rows).balances;
        return PhoneRow(
          title: 'Money',
          subtitle: balances.isEmpty
              ? 'Nothing recorded'
              : balances.entries
                    .map((e) => fmtMoney(e.value, e.key))
                    .join('  ·  '),
          chevron: true,
          // ⚠ No trailing icon. The other two rows have none, and one
          // decorative glyph on one row of three reads as a mistake rather
          // than a distinction.
          onTap: () =>
              PhoneReviewScreen._push(context, PhoneMoneyScreen(db: db)),
        );
      },
    );
  }
}

class _CountEntry<R> extends StatelessWidget {
  const _CountEntry({
    required this.title,
    required this.stream,
    required this.label,
    required this.onTap,
  });
  final String title;
  final Stream<List<R>> stream;
  final String Function(int) label;
  final void Function(BuildContext) onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<R>>(
      stream: stream,
      builder: (context, snap) => PhoneRow(
        title: title,
        subtitle: label(snap.data?.length ?? 0),
        chevron: true,
        onTap: () => onTap(context),
      ),
    );
  }
}
