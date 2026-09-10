import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// Phone-metric counterparts to `widgets/primitives.dart`.
///
/// ⚠ These are NOT the desktop primitives with bigger numbers. The desktop
/// list row hides its actions until hover — "they do not occupy space when
/// idle" — and a phone has no hover, so that pattern silently deletes every
/// row action. Nothing here is hover-conditional. If an action exists, it
/// occupies space.

/// Screen scaffold: 28pt title, optional trailing action, canvas ground.
/// No DragToMoveArea — there is no window to move.
class PhoneBody extends StatelessWidget {
  const PhoneBody({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
  });
  final String title;
  final Widget child;
  final Widget? trailing;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // ⚠ Material, not just a coloured Container. TextField asserts on a missing
    // Material ancestor, and relying on the shell's Scaffold to supply one
    // makes every screen here unusable on its own — including in a test.
    return Material(
      color: t.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  PD.screenPad, 12, PD.screenPad, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style:
                                PT.screenTitle.copyWith(color: t.textPrimary)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          subtitle!,
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            const SizedBox(height: PD.groupGap),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

enum PhoneBtnVariant { primary, secondary, ghost }

/// 48pt tall, and full width when [expand] is set. A phone button is pressed
/// with a thumb, so there is no small size.
class PhoneBtn extends StatelessWidget {
  const PhoneBtn(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = PhoneBtnVariant.secondary,
    this.icon,
    this.expand = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final PhoneBtnVariant variant;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final enabled = onPressed != null;
    Color bg;
    Color fg;
    Border? border;
    switch (variant) {
      case PhoneBtnVariant.primary:
        bg = t.accent;
        fg = t.textInverse;
      case PhoneBtnVariant.secondary:
        bg = t.card;
        fg = t.textPrimary;
        border = Border.all(color: t.line);
      case PhoneBtnVariant.ghost:
        bg = Colors.transparent;
        fg = t.textSecondary;
    }
    if (!enabled) {
      fg = t.textMuted;
      if (variant == PhoneBtnVariant.primary) bg = t.subtle;
    }

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: PD.control,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: BorderRadius.circular(D.radiusControl),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: PT.body.copyWith(color: fg, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Multi-select chip, 36pt. Used for occasion tags and ping intervals.
class PhoneChip extends StatelessWidget {
  const PhoneChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: PD.tag,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? t.accentWash : t.card,
          border: Border.all(color: selected ? t.accent : t.line),
          borderRadius: BorderRadius.circular(D.radiusControl),
        ),
        // ⚠ No `alignment:` here — setting it makes Container expand to the
        // max constraint, which in a Wrap means full width and one chip per
        // row. A Row with MainAxisSize.min centres the text and stays tight.
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: PT.secondary.copyWith(
                  color: selected ? t.accent : t.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

/// Label above, field below. Stacked, never side by side — two fields on one
/// phone row halves the tap target and gains nothing.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: PD.control),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(D.radiusControl),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            style: PT.body.copyWith(color: t.textPrimary),
            cursorColor: t.accent,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: hint,
              hintStyle: PT.body.copyWith(color: t.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

/// Group header. Sections with zero items are hidden entirely, never rendered
/// empty — the same rule as the Mac.
class PhoneSection extends StatelessWidget {
  const PhoneSection(this.title, this.children, {super.key});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: PD.groupHeader,
          alignment: Alignment.bottomLeft,
          child: Text(title.toUpperCase(),
              style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.6)),
        ),
        const SizedBox(height: 6),
        ...children,
        const SizedBox(height: PD.sectionGap),
      ],
    );
  }
}

/// ⚠ One calm line. No illustration, no icon, no button, no suggestions.
/// On Today this is the NORMAL state — most days nothing is due, and the
/// screen is quiet because nothing needed doing, not because it failed.
class PhoneEmpty extends StatelessWidget {
  const PhoneEmpty(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PD.screenPad),
        child: Text(text,
            textAlign: TextAlign.center,
            style: PT.body.copyWith(color: t.textMuted)),
      ),
    );
  }
}

/// A bordered surface. No shadow — the design system bans them, and a phone
/// full of floating cards is the tell that it was designed for a dribbble shot.
class PhoneCard extends StatelessWidget {
  const PhoneCard({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(D.radiusPanel),
        ),
        child: child,
      ),
    );
  }
}

/// The Mac's StatusTag at phone size. Dot plus text, never an icon.
class PhoneTag extends StatelessWidget {
  const PhoneTag({super.key, required this.tone, required this.label});
  final Tone tone;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: tone.wash,
          borderRadius: BorderRadius.circular(D.radiusTag),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: tone.dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: PT.micro.copyWith(color: tone.text)),
          ],
        ),
      );
}
