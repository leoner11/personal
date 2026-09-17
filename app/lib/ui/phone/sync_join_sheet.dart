import 'package:flutter/material.dart';

import '../../domain/sync_account.dart';
import '../../theme/tokens.dart';
import 'phone_primitives.dart';

/// "This device and this account both have data — combine, or replace?"
///
/// Returns the choice, or null for Not now. ⚠ Use the account's data asks
/// again behind the house confirm, naming what leaves the device; Combine
/// removes nothing, so it does not.
class PhoneSyncJoinSheet extends StatelessWidget {
  const PhoneSyncJoinSheet({super.key, required this.join});
  final JoinNeeded join;

  static Future<JoinChoice?> show(BuildContext context, JoinNeeded join) =>
      PhoneSheet.show<JoinChoice>(
          context, (_) => PhoneSyncJoinSheet(join: join));

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final q = joinQuestion(join);
    return PhoneSheet(
      title: q.title,
      actions: PhoneBtn('Not now',
          variant: PhoneBtnVariant.ghost,
          expand: true,
          onPressed: () => Navigator.pop(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.body, style: PT.secondary.copyWith(color: t.textSecondary)),
          const SizedBox(height: PD.sectionGap),
          PhoneRow(
            title: 'Combine both',
            subtitle: combineExplainer(join),
            chevron: true,
            onTap: () => Navigator.pop(context, JoinChoice.combine),
          ),
          const PhoneDivider(),
          PhoneRow(
            title: 'Use ${join.account}\'s data',
            subtitle: useAccountExplainer(join),
            chevron: true,
            onTap: () async {
              final c = replaceConfirm(join);
              final ok = await showPhoneConfirm(context,
                  title: c.title, body: c.body, confirmLabel: 'Replace');
              if (ok && context.mounted) {
                Navigator.pop(context, JoinChoice.useAccount);
              }
            },
          ),
        ],
      ),
    );
  }
}
