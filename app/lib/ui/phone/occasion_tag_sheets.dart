import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../domain/tag_vocab.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'phone_primitives.dart';

/// Confirms, then deletes the tag and everything pointing at it.
///
/// ⚠ THE CONFIRM NAMES THE BLAST RADIUS BEFORE IT ASKS. Deleting a tag is not
/// a cosmetic tidy: it takes the tag off everyone carrying it and soft-deletes
/// every occasion dated against it. The counts are read live so the sentence
/// is true at the moment it is shown — and the alternative, deleting the row
/// alone, would leave those occasions firing notifications for a tag with
/// nowhere left in the UI to explain them.
Future<bool> confirmDeleteOccasionTag(
    BuildContext context, AppDatabase db, OccasionTagRow row) async {
  final (people, occasions) = await db.occasionTagUsage(row.slug);
  if (!context.mounted) return false;

  final bits = <String>[
    if (people > 0)
      'removes it from $people ${people == 1 ? 'person' : 'people'}',
    if (occasions > 0)
      'deletes $occasions ${occasions == 1 ? 'occasion' : 'occasions'}',
  ];
  final body = bits.isEmpty
      ? 'Nothing uses this tag yet.'
      : '${bits.join(' and ')}.';

  final ok = await showPhoneConfirm(context,
      title: 'Delete ${row.label}?',
      body: body.substring(0, 1).toUpperCase() + body.substring(1));
  if (!ok) return false;

  await db.deleteOccasionTag(row.id);
  await TagVocab.refresh(db);
  return true;
}

/// The '+' at the end of a chip wrap. ⚠ Exists because the moment you discover
/// the vocabulary is short is the moment you are tagging someone — sending the
/// user to a settings screen mid-capture is how the 10-second budget dies.
class NewTagChip extends StatelessWidget {
  const NewTagChip({super.key, required this.db, required this.onCreated});
  final AppDatabase db;
  final ValueChanged<String> onCreated;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhonePressable(
      onTap: () async {
        final slug = await OccasionTagSheet.show(context, db);
        if (slug != null) onCreated(slug);
      },
      child: Container(
        // Matches PhoneChip exactly — same height, radius and resting colours.
        // It sits in the same Wrap and must read as one of them, not as a
        // button that wandered in.
        height: PD.tag,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(D.radiusControl),
          border: Border.all(color: t.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(Ic.add, size: 15, color: t.textSecondary),
            const SizedBox(width: 6),
            Text('New tag',
                style: PT.secondary.copyWith(color: t.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Add or rename a tag. Returns the slug on save.
class OccasionTagSheet extends StatefulWidget {
  const OccasionTagSheet({super.key, required this.db, this.existing});
  final AppDatabase db;
  final OccasionTagRow? existing;

  static Future<String?> show(BuildContext context, AppDatabase db,
          {OccasionTagRow? existing}) =>
      PhoneSheet.show<String>(context,
          (_) => OccasionTagSheet(db: db, existing: existing));

  @override
  State<OccasionTagSheet> createState() => _OccasionTagSheetState();
}

class _OccasionTagSheetState extends State<OccasionTagSheet> {
  late final _label =
      TextEditingController(text: widget.existing?.label ?? '');
  late final _hint = TextEditingController(text: widget.existing?.hint ?? '');
  late final _greeting =
      TextEditingController(text: widget.existing?.greeting ?? '');

  @override
  void initState() {
    super.initState();
    _label.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_label, _hint, _greeting]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final gone = await confirmDeleteOccasionTag(context, widget.db, e);
    if (gone && mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) return;

    final e = widget.existing;
    if (e != null) {
      // ⚠ RENAME EDITS THE LABEL, NEVER THE SLUG. The slug is what every
      // tagged person, occasion and money row carries; re-slugging on rename
      // would detach all of them at once and silently empty the audience.
      await widget.db.updateOccasionTag(e.id, OccasionTagsCompanion(
            label: Value(label),
            hint: Value(_hint.text.trim().isEmpty ? null : _hint.text.trim()),
            greeting: Value(_greeting.text.trim().isEmpty
                ? null
                : _greeting.text.trim()),
          ));
      await TagVocab.refresh(widget.db);
      if (mounted) Navigator.pop(context, e.slug);
      return;
    }

    final slug = await createOccasionTag(widget.db,
        label: label, hint: _hint.text, greeting: _greeting.text);
    if (mounted) Navigator.pop(context, slug);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final editing = widget.existing != null;
    return PhoneSheet(
      title: editing ? 'Edit tag' : 'New tag',
      actions: Row(children: [
        // ⚠ Delete lives here, not on a swipe or a row icon — same as the
        // project sheet. The list is a read surface and deleting a tag is
        // rare; §3.2 reserves swipe for frequent actions.
        if (editing)
          Expanded(
            child: PhoneBtn('Delete',
                variant: PhoneBtnVariant.danger, onPressed: _delete),
          )
        else
          Expanded(
              child: PhoneBtn('Cancel',
                  onPressed: () => Navigator.pop(context))),
        const SizedBox(width: 10),
        Expanded(
          child: PhoneBtn('Save',
              variant: PhoneBtnVariant.primary,
              onPressed: _label.text.trim().isEmpty ? null : _save),
        ),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhoneField(
              label: 'Name',
              controller: _label,
              hint: 'Hanukkah',
              autofocus: !editing),
          const SizedBox(height: PD.groupGap),
          PhoneField(
              label: 'Who it is for',
              controller: _hint,
              hint: 'Jewish contacts'),
          const SizedBox(height: 4),
          Text('Shown under the tag, to save you guessing later.',
              style: PT.secondary.copyWith(color: t.textMuted)),
          const SizedBox(height: PD.groupGap),
          PhoneField(
              label: 'Greeting',
              controller: _greeting,
              hint: 'Happy Hanukkah!'),
          const SizedBox(height: 4),
          // ⚠ States the resolution order plainly, because it is the one thing
          // about greetings that is not guessable from the screen.
          Text(
              'Used for this tag unless an occasion sets its own. '
              'Leave empty for the built-in wording.',
              style: PT.secondary.copyWith(color: t.textMuted)),
          if (editing) ...[
            const SizedBox(height: PD.sectionGap),
            Text('Renaming keeps everyone already tagged.',
                style: PT.secondary.copyWith(color: t.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// The vocabulary manager. Add, rename, reorder, delete.
///
/// ⚠ WHY THIS SCREEN EXISTS AT ALL. The nine built-in tags are Indonesian,
/// Malaysian and Chinese because that is who the author knows. For anyone else
/// the list is not merely incomplete — without this screen it is unfixable
/// from inside the app, and an untaggable contact is a festival that never
/// fires. The '+' chip covers adding one mid-capture; this covers the rest.
class PhoneOccasionTagsScreen extends StatefulWidget {
  const PhoneOccasionTagsScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PhoneOccasionTagsScreen> createState() =>
      _PhoneOccasionTagsScreenState();
}

class _PhoneOccasionTagsScreenState extends State<PhoneOccasionTagsScreen> {
  Future<void> _edit(OccasionTagRow row) async {
    await OccasionTagSheet.show(context, widget.db, existing: row);
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    await OccasionTagSheet.show(context, widget.db);
    if (mounted) setState(() {});
  }

  /// Persists the drag as explicit sortOrder values. ⚠ Rewrites every row, not
  /// just the moved one: sparse or duplicated orders make the next drag land
  /// somewhere the user did not aim.
  Future<void> _reorder(List<OccasionTagRow> rows, int from, int to) async {
    if (to > from) to -= 1;
    final next = [...rows];
    next.insert(to, next.removeAt(from));
    for (final (i, row) in next.indexed) {
      if (row.sortOrder == i) continue;
      await widget.db
          .updateOccasionTag(row.id, OccasionTagsCompanion(sortOrder: Value(i)));
    }
    await TagVocab.refresh(widget.db);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneScaffold(
      title: 'Occasion tags',
      actions: [
        PhonePressable(
          onTap: _add,
          pressedScale: 0.9,
          child: SizedBox(
            width: PD.tapMin,
            height: PD.tapMin,
            child: Center(child: AppIcon(Ic.add, size: 26, color: t.accent)),
          ),
        ),
      ],
      child: StreamBuilder<List<OccasionTagRow>>(
        stream: widget.db.watchOccasionTags(),
        builder: (context, snap) {
          final rows = snap.data ?? const <OccasionTagRow>[];
          if (rows.isEmpty) {
            return const PhoneEmpty('No tags yet — add the ones you send.');
          }
          // ⚠ THE LIST IS THE SCROLLABLE, not a shrink-wrapped child of a
          // Column. PhoneScaffold hands its child an unbounded-height slot and
          // expects it to scroll itself; wrapping this in a Column overflows
          // the moment the vocabulary outgrows the screen, which nine built-in
          // tags already do on a small phone.
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(
                PD.screenPad, 0, PD.screenPad, PD.sectionGap),
            header: Padding(
              padding: const EdgeInsets.only(bottom: PD.groupGap),
              child: Text(
                  'Who gets prompted for an occasion. '
                  'Drag to reorder the chips.',
                  style: PT.secondary.copyWith(color: t.textMuted)),
            ),
            itemCount: rows.length,
            onReorder: (f, tIdx) => _reorder(rows, f, tIdx),
            // ⚠ The default proxy paints a Material elevation shadow, and
            // shadows are out of house. Carry the row on the plain canvas.
            proxyDecorator: (child, _, _) =>
                Material(color: Colors.transparent, child: child),
            itemBuilder: (context, i) {
              final row = rows[i];
              return PhoneRow(
                key: ValueKey(row.id),
                title: row.label,
                subtitle: (row.hint ?? '').isEmpty ? null : row.hint,
                chevron: true,
                onTap: () => _edit(row),
              );
            },
          );
        },
      ),
    );
  }
}
