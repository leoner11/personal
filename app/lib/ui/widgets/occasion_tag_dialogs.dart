import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../domain/tag_vocab.dart';
import '../../theme/tokens.dart';
import 'primitives.dart';

/// Desktop half of the tag vocabulary. The phone has
/// `phone/occasion_tag_sheets.dart`; what a tag IS — slug minting, collision,
/// revival — is shared, and lives in [createOccasionTag] in domain/tag_vocab.
///
/// Add or rename a tag on the desktop. Returns the slug on save.
class NewTagDialog extends StatefulWidget {
  const NewTagDialog({super.key, required this.db, this.existing});
  final AppDatabase db;
  final OccasionTagRow? existing;

  static Future<String?> show(BuildContext context, AppDatabase db,
          {OccasionTagRow? existing}) =>
      showDialog<String>(
        context: context,
        builder: (_) => NewTagDialog(db: db, existing: existing),
      );

  @override
  State<NewTagDialog> createState() => _NewTagDialogState();
}

class _NewTagDialogState extends State<NewTagDialog> {
  late final _label = TextEditingController(text: widget.existing?.label ?? '');
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

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) return;
    final e = widget.existing;

    if (e != null) {
      // ⚠ RENAME EDITS THE LABEL, NEVER THE SLUG. The slug is what every
      // tagged person, occasion and money row carries; re-slugging on rename
      // detaches all of them at once and silently empties the audience.
      await widget.db.updateOccasionTag(
          e.id,
          OccasionTagsCompanion(
            label: Value(label),
            hint: Value(_hint.text.trim().isEmpty ? null : _hint.text.trim()),
            greeting: Value(
                _greeting.text.trim().isEmpty ? null : _greeting.text.trim()),
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
    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(editing ? 'Edit tag' : 'New tag',
                  style: T.entityName.copyWith(color: t.textPrimary)),
              const SizedBox(height: 12),
              Field(
                  label: 'Name',
                  controller: _label,
                  hint: 'Hanukkah',
                  autofocus: !editing),
              const SizedBox(height: 10),
              Field(
                  label: 'Who it is for',
                  controller: _hint,
                  hint: 'Jewish contacts'),
              const SizedBox(height: 10),
              Field(
                  label: 'Greeting',
                  controller: _greeting,
                  hint: 'Happy Hanukkah!',
                  maxLines: 2),
              const SizedBox(height: 6),
              // ⚠ States the resolution order plainly — it is the one thing
              // about greetings not guessable from the screen.
              Text(
                  'Used for this tag unless an occasion sets its own. '
                  'Leave empty for the built-in wording.',
                  style: T.secondary.copyWith(color: t.textMuted)),
              if (editing) ...[
                const SizedBox(height: 6),
                Text('Renaming keeps everyone already tagged.',
                    style: T.secondary.copyWith(color: t.textMuted)),
              ],
              const SizedBox(height: 16),
              Row(children: [
                if (editing)
                  DeleteAction(
                    what: widget.existing!.label,
                    onConfirmed: () async {
                      await widget.db
                          .deleteOccasionTag(widget.existing!.id);
                      await TagVocab.refresh(widget.db);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                const Spacer(),
                Btn('Cancel', onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn('Save',
                    variant: BtnVariant.primary,
                    onPressed: _label.text.trim().isEmpty ? null : _save),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
