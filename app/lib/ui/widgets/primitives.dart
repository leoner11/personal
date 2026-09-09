import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

/// Three variants, two sizes. That is the whole set.
enum BtnVariant { primary, secondary, ghost }

enum BtnSize { sm, md }

class Btn extends StatefulWidget {
  const Btn(this.label,
      {super.key,
      this.onPressed,
      this.variant = BtnVariant.secondary,
      this.size = BtnSize.md,
      this.icon});

  final String label;
  final VoidCallback? onPressed;
  final BtnVariant variant;
  final BtnSize size;
  final IconData? icon;

  @override
  State<Btn> createState() => _BtnState();
}

class _BtnState extends State<Btn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final sm = widget.size == BtnSize.sm;
    final enabled = widget.onPressed != null;

    Color bg, fg;
    BoxBorder? border;
    switch (widget.variant) {
      case BtnVariant.primary:
        bg = _hover ? t.accentHover : t.accent;
        fg = t.textInverse;
      case BtnVariant.secondary:
        bg = _hover ? t.subtle : t.card;
        fg = t.textPrimary;
        border = Border.all(color: t.line);
      case BtnVariant.ghost:
        bg = _hover ? t.subtle : Colors.transparent;
        fg = t.textSecondary;
    }
    if (!enabled) fg = t.textMuted;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: sm ? 22 : D.control,
          padding: EdgeInsets.symmetric(horizontal: sm ? 8 : 14),
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(D.radiusControl),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 14, color: fg),
                const SizedBox(width: 5),
              ],
              Text(widget.label,
                  style: TextStyle(
                      fontSize: sm ? 11 : 13,
                      fontWeight: FontWeight.w500,
                      color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Takes a semantic tone, never guesses from a string. Always carries a label —
/// meaning is never encoded in colour alone.
class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.tone, required this.label});
  final Tone tone;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: D.tag,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: tone.wash,
          borderRadius: BorderRadius.circular(D.radiusTag),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: tone.dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: T.micro.copyWith(color: tone.text)),
        ]),
      );
}

/// White panel, line border, 8pt radius, no shadow. Nothing floats.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(D.radiusPanel),
      ),
      child: child,
    );
  }
}

/// One calm line, centred. No icon, no illustration, no mascot.
class EmptyLine extends StatelessWidget {
  const EmptyLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
      child: Text(text,
          style: T.body.copyWith(color: AppTokens.of(context).textMuted)));
}

/// Label above the field, 10pt uppercase muted. Never a floating label,
/// never placeholder-as-label. Optional is the default — no required markers.
class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.width,
    this.maxLines = 1,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final double? width;
  final int maxLines;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            autofocus: autofocus,
            style: T.body.copyWith(color: t.textPrimary),
            cursorColor: t.accent,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: t.card,
              hintText: hint,
              hintStyle: T.body.copyWith(color: t.textMuted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(D.radiusControl),
                borderSide: BorderSide(color: t.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(D.radiusControl),
                borderSide: BorderSide(color: t.accent, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-select chip. The one field worth being slightly annoying about.
class TagChip extends StatelessWidget {
  const TagChip(
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
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? t.accentWash : t.card,
            border: Border.all(color: selected ? t.accent : t.line),
            borderRadius: BorderRadius.circular(D.radiusControl),
          ),
          // ⚠ No `alignment:` here — setting it makes Container expand to the
          // max constraint, which in a Wrap means full width, one chip a row.
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: T.secondary.copyWith(
                    color: selected ? t.accent : t.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

/// Date control. A read-out plus quick offsets, because most dates in this app
/// are "a few weeks out" rather than an exact day picked from a grid.
class DateField extends StatelessWidget {
  const DateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.offsets = const [('today', 0), ('+1w', 7), ('+1mo', 30), ('+3mo', 90)]});

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final List<(String, int)> offsets;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        // ⚠ Wrap, not Row. These are fixed-width children that cannot shrink,
        // so a Row overflows the moment the pane is narrow.
        Wrap(spacing: 6, runSpacing: 6, children: [
          Btn(_fmt(value), size: BtnSize.sm, onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) onChanged(picked);
          }),
          for (final (name, days) in offsets)
            TagChip(
              label: name,
              selected: false,
              onTap: () {
                final n = DateTime.now();
                onChanged(DateTime(n.year, n.month, n.day + days));
              },
            ),
        ]),
      ],
    );
  }

  static const _m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static String _fmt(DateTime d) => '${d.day} ${_m[d.month - 1]} ${d.year}';
}

/// ⚠ Destructive actions are ghost + danger text, always behind a confirm.
/// There is no filled danger button — nothing in this app is destructive
/// enough to earn one, and every delete is soft.
class DeleteAction extends StatelessWidget {
  const DeleteAction(
      {super.key,
      required this.what,
      required this.onConfirmed,
      this.label = 'Delete',
      this.size = BtnSize.sm});

  final String what;
  final Future<void> Function() onConfirmed;
  final String label;
  final BtnSize size;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Btn(label, size: size, variant: BtnVariant.ghost, onPressed: () async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => Dialog(
          backgroundColor: t.canvas,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(D.radiusPanel)),
          child: SizedBox(
            width: 340,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delete $what?',
                      style: T.entityName.copyWith(color: t.textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                      'It stops appearing everywhere, but the row is kept so '
                      'the other device learns it is gone.',
                      style: T.secondary.copyWith(color: t.textSecondary)),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Btn('Cancel',
                        variant: BtnVariant.secondary,
                        onPressed: () => Navigator.pop(c, false)),
                    const SizedBox(width: 8),
                    Btn('Delete',
                        variant: BtnVariant.ghost,
                        onPressed: () => Navigator.pop(c, true)),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
      if (ok == true) await onConfirmed();
    });
  }
}
