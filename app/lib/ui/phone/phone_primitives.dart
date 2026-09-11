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

/// A modal bottom sheet, which is how every edit on the phone happens.
///
/// ⚠ Sheets, not pushes. The design spec allows nothing more than one push
/// deep from a tab, and Review → Money → edit would be two. A sheet is a
/// modal over the current screen, not another level of the stack.
///
/// Two things here are load-bearing on a phone and absent from the Mac dialog
/// this replaces:
///   - The whole sheet lifts by `viewInsets.bottom`, so the keyboard never
///     covers the field being typed into.
///   - [actions] are pinned below the scroll area, so Save stays reachable
///     without scrolling to the end of a long form.
class PhoneSheet extends StatelessWidget {
  const PhoneSheet({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.expand = false,
  });
  final String title;
  final Widget child;

  /// Pinned to the bottom, above the keyboard. Usually Cancel + a primary.
  final Widget? actions;

  /// Take nearly the full screen and let [child] fill it — for the note
  /// editor, which needs room to be a place you actually write.
  final bool expand;

  static Future<R?> show<R>(BuildContext context, WidgetBuilder builder) =>
      showModalBottomSheet<R>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        // The form behind it is still the context; dismissing must not feel
        // like leaving the screen.
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: builder,
      );

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final h = MediaQuery.sizeOf(context).height;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(
        PD.screenPad,
        0,
        PD.screenPad,
        PD.sectionGap,
      ),
      child: child,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // ⚠ Material, not just a coloured Container — the same rule as
      // [PhoneBody]. TextField asserts on a missing Material ancestor, and
      // leaning on showModalBottomSheet to supply one makes every sheet here
      // unusable on its own, including in a test.
      child: Material(
        color: t.canvas,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(D.radiusPanel * 2),
        ),
        child: Container(
          constraints: BoxConstraints(maxHeight: h * (expand ? 0.94 : 0.88)),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(D.radiusPanel * 2),
            ),
            border: Border.all(color: t.line),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The grabber. The only ornament allowed here, and it earns its
                // place: it is the affordance that says this can be dragged away.
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    decoration: BoxDecoration(
                      color: t.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PD.screenPad,
                    0,
                    PD.screenPad,
                    PD.groupGap,
                  ),
                  child: Text(
                    title,
                    style: PT.entityName.copyWith(color: t.textPrimary),
                  ),
                ),
                if (expand)
                  Expanded(child: body)
                else
                  Flexible(child: SingleChildScrollView(child: body)),
                if (actions != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      PD.screenPad,
                      10,
                      PD.screenPad,
                      10,
                    ),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: t.line)),
                    ),
                    child: actions,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable list row, one or two lines.
///
/// ⚠ Nothing here is hover-conditional — see the note at the top of this file.
/// Any action the row offers is a [trailing] widget that always occupies space.
class PhoneRow extends StatelessWidget {
  const PhoneRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.titleStyle,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final twoLine = subtitle != null && subtitle!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(
          minHeight: twoLine ? PD.listRowTwoLine : PD.listRow,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        titleStyle ??
                        PT.body.copyWith(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (twoLine) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PT.secondary.copyWith(color: t.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            if (chevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 20, color: t.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}

/// A hairline between list rows. Never around them — the design system bans
/// boxing every row, and a phone list of bordered cards is the tell.
class PhoneDivider extends StatelessWidget {
  const PhoneDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppTokens.of(context).line);
}
