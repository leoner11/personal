import 'package:flutter/material.dart';

import '../domain/sync_account.dart';
import '../theme/tokens.dart';
import 'widgets/primitives.dart';

/// Desktop half of "combine, or replace?". Same question and wording as
/// `phone/sync_join_sheet.dart` — both come from domain/sync_account.dart.
/// Returns the choice, or null for Not now.
class SyncJoinDialog extends StatelessWidget {
  const SyncJoinDialog({super.key, required this.join});
  final JoinNeeded join;

  static Future<JoinChoice?> show(BuildContext context, JoinNeeded join) =>
      showDialog<JoinChoice>(
        context: context,
        // ⚠ No dismiss-by-clicking-outside. A stray click must not read as an
        // answer; Not now is an explicit button.
        barrierDismissible: false,
        builder: (_) => SyncJoinDialog(join: join),
      );

  Future<bool> _confirmReplace(BuildContext context) async {
    final t = AppTokens.of(context);
    final c = replaceConfirm(join);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: t.canvas,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(D.radiusPanel)),
        child: SizedBox(
          width: 360,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title,
                    style: T.entityName.copyWith(color: t.textPrimary)),
                const SizedBox(height: 6),
                Text(c.body,
                    style: T.secondary.copyWith(color: t.textSecondary)),
                const SizedBox(height: 16),
                Row(children: [
                  const Spacer(),
                  Btn('Cancel',
                      variant: BtnVariant.ghost,
                      onPressed: () => Navigator.pop(ctx, false)),
                  const SizedBox(width: 8),
                  Btn('Replace', onPressed: () => Navigator.pop(ctx, true)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final q = joinQuestion(join);

    Widget option(String title, String body, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: T.body.copyWith(
                            color: t.textPrimary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(body,
                        style: T.secondary.copyWith(color: t.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Btn('Choose', size: BtnSize.sm, onPressed: onTap),
            ]),
          ),
        );

    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q.title, style: T.entityName.copyWith(color: t.textPrimary)),
              const SizedBox(height: 6),
              Text(q.body, style: T.secondary.copyWith(color: t.textSecondary)),
              const SizedBox(height: 16),
              option('Combine both', combineExplainer(join),
                  () => Navigator.pop(context, JoinChoice.combine)),
              option('Use ${join.account}\'s data', useAccountExplainer(join),
                  () async {
                if (await _confirmReplace(context) && context.mounted) {
                  Navigator.pop(context, JoinChoice.useAccount);
                }
              }),
              Row(children: [
                const Spacer(),
                Btn('Not now',
                    variant: BtnVariant.ghost,
                    onPressed: () => Navigator.pop(context)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
