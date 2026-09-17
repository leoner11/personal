import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';

/// Phone-metric counterparts to `widgets/primitives.dart`, rebuilt for v2.
///
/// ⚠ These are NOT the desktop primitives with bigger numbers. The desktop
/// list row hides its actions until hover — "they do not occupy space when
/// idle" — and a phone has no hover, so that pattern silently deletes every
/// row action. Nothing here is hover-conditional. If an action exists, it
/// occupies space.
///
/// v2 adds the mobile grammar the v1 port never had (Phone Design v2.0 §3):
/// every tappable thing yields on press ([PhonePressable]), every field shows
/// focus ([PhoneField]), sheets spring ([PhoneSheet]), the large title
/// collapses on scroll ([PhoneScaffold]), and destruction goes through the
/// house confirm panel ([showPhoneConfirm]) — never a default dialog.

/// Haptics are confirmations, not decoration (§3.4). Light fires when a
/// swipe action or check lands; warning only on destructive confirms.
class PhoneHaptic {
  PhoneHaptic._();
  static void light() => HapticFeedback.lightImpact();
  static void warning() => HapticFeedback.heavyImpact();
}

/// Scale-down-on-press wrapper. The house answer to the Material splash:
/// the surface yields toward the thumb and springs back on release. Wrap any
/// tappable surface; [onTap] is optional so press feedback can be layered
/// onto widgets that own their own gesture routing.
class PhonePressable extends StatefulWidget {
  const PhonePressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<PhonePressable> createState() => _PhonePressableState();
}

class _PhonePressableState extends State<PhonePressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: PM.pressMs),
          curve: PM.pop,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Screen scaffold with the collapsing large title (§3.1). The 28pt title is
/// the one place the phone is bigger than the Mac's 20pt ceiling — a phone
/// header has no window chrome to signal "new screen", so type does it alone.
/// Past ~26px of scroll the title folds into a 17pt inline bar with a
/// hairline; the actions (44pt targets, icons not words) never move.
///
/// ⚠ The bar overlays the header rather than reclaiming its height: the
/// large title fades and scales away in place, so nothing below jumps.
/// Subtitle (person detail's company line) lives under the large title and
/// folds away with it.
class PhoneScaffold extends StatefulWidget {
  const PhoneScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    this.collapsible = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final bool collapsible;

  @override
  State<PhoneScaffold> createState() => _PhoneScaffoldState();
}

class _PhoneScaffoldState extends State<PhoneScaffold> {
  bool _collapsed = false;

  bool _onScroll(ScrollNotification n) {
    if (!widget.collapsible || n is! ScrollUpdateNotification) return false;
    final collapsed = n.metrics.pixels > 26;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // ⚠ Material, not just a coloured Container. TextField asserts on a
    // missing Material ancestor, and every screen here must also work
    return Material(
      color: t.canvas,
      // ⚠ Top SafeArea is load-bearing: without it the large title slides
      // under the Dynamic Island / notch. Bottom stays false — the shell's
      // tab bar owns that inset.
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.ease,
            decoration: BoxDecoration(
              color: t.canvas,
              border: _collapsed
                  ? Border(bottom: BorderSide(color: t.line))
                  : null,
            ),
            padding:
                const EdgeInsets.fromLTRB(PD.screenPad, 10, PD.screenPad, 4),
            child: Row(
              crossAxisAlignment: _collapsed
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: SizedBox(
                    height: _collapsed ? PD.control : null,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // The large title. Fades and folds away in place —
                        // the bar below fades in over the same space, so
                        // nothing under the header ever jumps.
                        AnimatedOpacity(
                          opacity: _collapsed ? 0 : 1,
                          duration: const Duration(milliseconds: 160),
                          child: AnimatedScale(
                            scale: _collapsed ? 0.95 : 1,
                            duration: const Duration(milliseconds: 180),
                            curve: PM.pop,
                            alignment: Alignment.bottomLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.title,
                                    style: PT.screenTitle
                                        .copyWith(color: t.textPrimary)),
                                if (widget.subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(widget.subtitle!,
                                      style: PT.secondary
                                          .copyWith(color: t.textSecondary)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: _collapsed ? 1 : 0,
                          duration: const Duration(milliseconds: 140),
                          child: Text(widget.title,
                              style: PT.body.copyWith(
                                  color: t.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  // The mockup's inline bar tracks like a
                                  // title (-.01em), not like body text.
                                  letterSpacing: -0.17)),
                        ),
                      ],
                    ),
                  ),
                ),
                ...widget.actions,
              ],
            ),
          ),
          const SizedBox(height: PD.groupGap - 6),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.child,
            ),
          ),
          ],
        ),
        ),
    );
  }
}

enum PhoneBtnVariant { primary, secondary, ghost, danger }

/// 48pt tall, and full width when [expand] is set. A phone button is pressed
/// with a thumb, so there is no small size. `danger` is the ghost style in
/// `danger.text` — the destructive confirm voice (§3.3). There is no filled
/// danger button: nothing in this app is destructive enough to earn one.
class PhoneBtn extends StatefulWidget {
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
  State<PhoneBtn> createState() => _PhoneBtnState();
}

class _PhoneBtnState extends State<PhoneBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final enabled = widget.onPressed != null;
    Color bg;
    Color fg;
    Border? border;
    switch (widget.variant) {
      case PhoneBtnVariant.primary:
        bg = _down && enabled ? t.accentHover : t.accent;
        fg = t.textInverse;
      case PhoneBtnVariant.secondary:
        bg = _down && enabled ? t.subtle : t.card;
        fg = t.textPrimary;
        border = Border.all(color: t.line);
      case PhoneBtnVariant.ghost:
        bg = _down && enabled ? t.subtle : Colors.transparent;
        fg = t.textSecondary;
      case PhoneBtnVariant.danger:
        bg = _down && enabled ? t.subtle : Colors.transparent;
        fg = t.danger.text;
    }
    if (!enabled) {
      fg = t.textMuted;
      if (widget.variant == PhoneBtnVariant.primary) bg = t.subtle;
    }

    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _down && enabled ? 0.97 : 1,
          duration: const Duration(milliseconds: PM.pressMs),
          curve: PM.pop,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: PD.control,
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: bg,
              border: border,
              borderRadius: BorderRadius.circular(D.radiusControl),
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(widget.label,
                    style: PT.body
                        .copyWith(color: fg, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Multi-select chip, 36pt. Used for occasion tags and ping intervals.
/// Selecting pops the chip (§3.6) — the one bit of celebration a quiet tool
/// allows itself, because selection is the thumb being answered.
class PhoneChip extends StatefulWidget {
  const PhoneChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<PhoneChip> createState() => _PhoneChipState();
}

class _PhoneChipState extends State<PhoneChip> {
  int _popTick = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: () {
        final becameSelected = !widget.selected;
        widget.onTap();
        // The pop replays on every fresh selection: the tween restarts
        // because the key changes, which is the whole trick.
        if (becameSelected) setState(() => _popTick++);
      },
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_popTick),
        tween: Tween(begin: 0.92, end: 1),
        duration: const Duration(milliseconds: 340),
        curve: PM.pop,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: PD.tag,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: widget.selected ? t.accentWash : t.card,
            border:
                Border.all(color: widget.selected ? t.accent : t.line),
            borderRadius: BorderRadius.circular(D.radiusControl),
          ),
          // ⚠ No `alignment:` here — setting it makes Container expand to the
          // max constraint, which in a Wrap means full width and one chip per
          // row. A Row with MainAxisSize.min centres the text and stays tight.
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.label,
                style: PT.secondary.copyWith(
                    color: widget.selected ? t.accent : t.textSecondary,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

/// Label above, field below. Stacked, never side by side — two fields on one
/// phone row halves the tap target and gains nothing.
///
/// v2: the border swaps to `accent` on focus (desktop `Field` parity — the v1
/// field never changed on focus, which read as dead glass). [obscure],
/// [autocorrect] and [enableSuggestions] back the Account password field;
/// [textInputAction] is how the keyboard accessory Next/Done is expressed;
/// [onSubmitted] is its verb — Capture wires "Done saves when the form is
/// valid" there (IME actions are not observable from a FocusNode, so the
/// TextField passes them straight through); [suffix] carries field-level
/// actions like the password reveal.
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.focusNode,
    this.obscure = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final bool obscure;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  FocusNode? _internal;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_internal ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(PhoneField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode?.removeListener(_onFocus);
      _internal?.removeListener(_onFocus);
      _node.addListener(_onFocus);
      _onFocus();
    }
  }

  void _onFocus() {
    final f = _node.hasFocus;
    if (f != _focused) setState(() => _focused = f);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _internal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(),
            style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: PD.control),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(
              color: _focused ? t.accent : t.line,
              width: _focused ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(D.radiusControl),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _node,
                  autofocus: widget.autofocus,
                  keyboardType: widget.keyboardType,
                  textCapitalization: widget.textCapitalization,
                  obscureText: widget.obscure,
                  autocorrect: widget.autocorrect,
                  enableSuggestions: widget.enableSuggestions,
                  textInputAction: widget.textInputAction,
                  onSubmitted: widget.onSubmitted,
                  style: PT.body.copyWith(color: t.textPrimary),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.hint,
                    hintStyle: PT.body.copyWith(color: t.textMuted),
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
            ],
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
/// full of floating cards is the tell that it was designed for a dribbble
/// shot. v2: tappable cards yield to the thumb (scale + warm tint).
class PhoneCard extends StatelessWidget {
  const PhoneCard({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final card = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(D.radiusPanel),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PhonePressable(
      onTap: onTap,
      pressedScale: 0.975,
      child: card,
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
/// Three things here are load-bearing on a phone and absent from the Mac
/// dialog this replaces:
///   - The whole sheet lifts by `viewInsets.bottom`, so the keyboard never
///     covers the field being typed into.
///   - [actions] are pinned below the scroll area, so Save stays reachable
///     without scrolling to the end of a long form.
///   - v2: the sheet SPRINGS (§3.6, PM.sheet) and drags away with the thumb —
///     the platform's own dismiss gesture on the house curve. The default
///     (non-expand) height is the medium detent; [expand] is the large one.
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
        sheetAnimationStyle: AnimationStyle(
          duration: const Duration(milliseconds: PM.sheetMs),
          curve: PM.sheet,
          reverseDuration: const Duration(milliseconds: 240),
        ),
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
      // [PhoneScaffold]. TextField asserts on a missing Material ancestor, and
      // leaning on showModalBottomSheet to supply one makes every sheet here
      // unusable on its own, including in a test.
      child: Material(
        color: t.canvas,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PD.sheetRadius),
        ),
        child: Container(
          constraints: BoxConstraints(maxHeight: h * (expand ? 0.94 : 0.88)),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PD.sheetRadius),
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
/// Any action the row offers is a [trailing] widget that always occupies
/// space. v2: rows yield to the thumb when tappable, the chevron comes from
/// the house icon set (the Material glyph died with the v2 migration), and
/// [leading] carries menu and hub icons.
class PhoneRow extends StatelessWidget {
  const PhoneRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.chevron = false,
    this.titleStyle,
    this.minHeight,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool chevron;
  final TextStyle? titleStyle;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final twoLine = subtitle != null && subtitle!.isNotEmpty;
    final row = Container(
      constraints: BoxConstraints(
        minHeight: minHeight ?? (twoLine ? PD.listRowTwoLine : PD.listRow),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
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
            AppIcon(Ic.chevronRight, size: 20, color: t.textMuted),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return PhonePressable(onTap: onTap, child: row);
  }
}

/// The house destructive confirm (§3.3) — every destructive act on the phone
/// goes through here and nowhere else. Panel grammar from the desktop's
/// DeleteAction: the title asks, the body explains the soft delete, Cancel is
/// secondary and the confirm is a **ghost in `danger.text`**. No filled
/// danger button exists; nothing in this app is destructive enough to earn
/// one. Returns true when confirmed.
Future<bool> showPhoneConfirm(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Delete',
}) {
  final t = AppTokens.of(context);
  return PhoneSheet.show<bool>(
    context,
    (context) => PhoneSheet(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: PT.secondary.copyWith(color: t.textSecondary)),
          const SizedBox(height: PD.sectionGap),
          Row(
            children: [
              Expanded(
                child: PhoneBtn('Cancel',
                    onPressed: () => Navigator.pop(context, false)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PhoneBtn(confirmLabel,
                    variant: PhoneBtnVariant.danger,
                    onPressed: () {
                      PhoneHaptic.warning();
                      Navigator.pop(context, true);
                    }),
              ),
            ],
          ),
        ],
      ),
    ),
  ).then((confirmed) => confirmed ?? false);
}

/// One row of a long-press context menu (§3.2). The verbs are the detail
/// screen's verbs — a menu never invents new ones.
class PhoneMenuItem {
  const PhoneMenuItem(this.label, {this.icon, this.onTap, this.danger = false});
  final String label;
  final Ic? icon;
  final VoidCallback? onTap;
  final bool danger;
}

/// The long-press menu as a medium sheet (§3.2). A Material popup menu
/// cannot carry house tokens on both platforms; one sheet implementation
/// serves iOS and Android identically and keeps "sheets, not pushes".
Future<void> showPhoneMenu(
  BuildContext context, {
  String? title,
  required List<PhoneMenuItem> items,
}) {
  final t = AppTokens.of(context);
  return PhoneSheet.show(
    context,
    (context) => PhoneSheet(
      title: title ?? '',
      child: Column(
        children: [
          for (final item in items)
            PhoneRow(
              title: item.label,
              minHeight: PD.control,
              leading: item.icon == null
                  ? null
                  : AppIcon(item.icon!,
                      size: 20,
                      color: item.danger ? t.danger.text : t.textSecondary),
              titleStyle:
                  item.danger ? PT.body.copyWith(color: t.danger.text) : null,
              onTap: () {
                Navigator.pop(context);
                item.onTap?.call();
              },
            ),
        ],
      ),
    ),
  );
}

/// Dismissible background for a single trailing swipe action (§3.2: trailing
/// swipe, ONE primary action per list — destructive swipes still confirm
/// before acting). Reused by People, Tasks and Notes so all three lists
/// reveal actions with identical geometry.
class PhoneSwipeBackground extends StatelessWidget {
  const PhoneSwipeBackground({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  /// The wash behind the revealed action; text and icon sit on it.
  final Color color;
  final String label;
  final Ic icon;

  @override
  Widget build(BuildContext context) {
    final onColor = AppTokens.of(context).textInverse;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: PD.screenPad),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(D.radiusPanel),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 18, color: onColor),
          const SizedBox(width: 8),
          Text(label,
              style: PT.secondary.copyWith(
                  color: onColor, fontWeight: FontWeight.w600)),
        ],
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
