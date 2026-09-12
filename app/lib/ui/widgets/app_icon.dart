import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/tokens.dart';

/// Every icon in the app goes through here. Stroke and size are set once,
/// never per-icon, and no screen file imports LucideIcons directly.
enum Ic {
  today(LucideIcons.sun),
  calendar(LucideIcons.calendar),
  occasions(LucideIcons.gift),
  people(LucideIcons.users),
  projects(LucideIcons.folderOpen),
  money(LucideIcons.wallet),
  notes(LucideIcons.fileText),
  message(LucideIcons.messageCircle),
  snooze(LucideIcons.clock),
  dismiss(LucideIcons.x),
  confirm(LucideIcons.check),
  add(LucideIcons.plus),
  ping(LucideIcons.bell),
  sync(LucideIcons.refreshCw),
  search(LucideIcons.search),
  copy(LucideIcons.copy);

  const Ic(this.glyph);
  final IconData glyph;
}

enum IconScale { nav, inline, row }

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon,
      {super.key, this.scale = IconScale.inline, this.color});

  final Ic icon;
  final IconScale scale;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
        icon.glyph,
        size: switch (scale) {
          IconScale.nav => 16,
          IconScale.inline => 14,
          IconScale.row => 12,
        },
        color: color ?? AppTokens.of(context).textSecondary,
      );
}
