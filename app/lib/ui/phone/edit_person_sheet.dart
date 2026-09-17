import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/tag_vocab.dart';
import '../../theme/tokens.dart';
import 'phone_pickers.dart' show PhoneDateRow;
import 'occasion_tag_sheets.dart';
import 'phone_primitives.dart';

/// Editing a person on the phone.
///
/// ⚠ A SHEET, NOT A PUSH. Person detail is already one push from the People
/// tab, and the design spec allows nothing more than one push deep. v2 keeps
/// that and moves the sheet to the LARGE detent: met where/met when joined the
/// form (§7 fix — capture-time fields had become permanently wrong-by-default
/// with no edit path anywhere), plus a delete footer, and neither fits a
/// medium sheet comfortably.
///
/// ⚠ EDITING IS LOOSER THAN CAPTURING. Capture demands a channel because you
/// are in front of the person and have it. Editing is usually admin — adding a
/// tag weeks later — and demanding a number you do not have would strand the
/// row. So this saves without one, and says so where you can see it.
class PhoneEditPersonSheet extends StatefulWidget {
  const PhoneEditPersonSheet(
      {super.key, required this.db, required this.person});
  final AppDatabase db;
  final Person person;

  @override
  State<PhoneEditPersonSheet> createState() => _PhoneEditPersonSheetState();
}

class _PhoneEditPersonSheetState extends State<PhoneEditPersonSheet> {
  late final _name = TextEditingController(text: widget.person.name);
  late final _company =
      TextEditingController(text: widget.person.company ?? '');
  late final _wa = TextEditingController(text: widget.person.waNumber ?? '');
  late final _wechat =
      TextEditingController(text: widget.person.wechatId ?? '');
  late final _metWhere =
      TextEditingController(text: widget.person.metWhere ?? '');
  late final _notes = TextEditingController(text: widget.person.notes ?? '');

  /// The picked meeting date. Null means "never touched" — the row DISPLAYS a
  /// candidate day either way (a date row needs a value), but only a pick
  /// writes. ⚠ Saving an untouched sheet must not stamp `now` onto an
  /// imported row with no date: metWhen records when you MET, and a guess is
  /// worse than an honest blank.
  DateTime? _metWhen;
  /// Slugs, not enum values — the vocabulary is a table now.
  final _tags = <String>{};

  @override
  void initState() {
    super.initState();
    // ⚠ EVERY slug is kept, including ones with no row in the vocabulary yet.
    // The old code skipped unknown tags on load and then wrote _tags back over
    // the person on save, which silently DELETED them. That needed a version
    // skew to trigger while the tag list was a compiled-in enum; now that tags
    // are user data it is a Tuesday — make a tag on the phone, edit that
    // person on the Mac before sync lands, and the tag was gone. Unknown slugs
    // are held in [_unknown], drawn as chips with their raw slug as the label,
    // and written back untouched.
    _tags.addAll(widget.person.occasionTags);
    for (final c in [_name, _wa, _wechat]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _company, _wa, _wechat, _metWhere, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasChannel =>
      _wa.text.trim().isNotEmpty || _wechat.text.trim().isNotEmpty;

  /// Keeps the stored preference while it is still reachable, so editing a
  /// note does not silently move someone from WeChat to WhatsApp.
  String get _preferred {
    final wa = _wa.text.trim();
    final wechat = _wechat.text.trim();
    final current = widget.person.preferredChannel;
    if (current == 'wa' && wa.isNotEmpty) return 'wa';
    if (current == 'wechat' && wechat.isNotEmpty) return 'wechat';
    return wa.isNotEmpty ? 'wa' : 'wechat';
  }

  Future<void> _save() async {
    final wa = _wa.text.trim();
    final wechat = _wechat.text.trim();
    final metWhere = _metWhere.text.trim();
    await widget.db.updatePerson(
      widget.person.id,
      PeopleCompanion(
        name: Value(_name.text.trim()),
        company:
            Value(_company.text.trim().isEmpty ? null : _company.text.trim()),
        waNumber: Value(wa.isEmpty ? null : wa),
        wechatId: Value(wechat.isEmpty ? null : wechat),
        preferredChannel: Value(_preferred),
        metWhere:
            Value(metWhere.isEmpty ? null : metWhere),
        // Only a real pick writes the date (see [_metWhen]).
        metWhen: _metWhen == null
            ? const Value.absent()
            : Value(_metWhen),
        notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
        occasionTags: Value(_tags.toList()),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  /// The house confirm panel, then the double pop: the sheet, then the person
  /// detail beneath it — deletion is admin done from the detail screen, so
  /// landing on a deleted record afterwards would be wrong. The warning
  /// haptic fires inside [showPhoneConfirm], on the destructive confirm only.
  Future<void> _delete() async {
    // Captured before the first await — the context may be defunct by the
    // time the confirms and writes settle, the navigator is not.
    final nav = Navigator.of(context);
    final ok = await showPhoneConfirm(
      context,
      title: 'Delete ${widget.person.name}?',
      body: 'The row is kept so the other device learns it is gone.',
    );
    if (!ok) return;
    await widget.db.softDelete(widget.person.id);
    if (mounted && nav.canPop()) nav..pop()..pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneSheet(
      title: 'Edit person',
      expand: true,
      actions: Row(children: [
        Expanded(
          child: PhoneBtn('Cancel',
              variant: PhoneBtnVariant.ghost,
              onPressed: () => Navigator.pop(context)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PhoneBtn('Save',
              variant: PhoneBtnVariant.primary,
              onPressed: _name.text.trim().isEmpty ? null : _save),
        ),
      ]),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhoneField(label: 'Name', controller: _name),
          const SizedBox(height: PD.groupGap),
          PhoneField(label: 'Company', controller: _company),
          const SizedBox(height: PD.groupGap),
          PhoneField(
              label: 'WhatsApp',
              controller: _wa,
              hint: '628123456789',
              keyboardType: TextInputType.phone,
              textCapitalization: TextCapitalization.none),
          const SizedBox(height: PD.groupGap),
          PhoneField(
              label: 'WeChat',
              controller: _wechat,
              textCapitalization: TextCapitalization.none),
          if (!_hasChannel) ...[
            const SizedBox(height: 8),
            // ⚠ Visible, not silent. Letting the edit through is the
            // concession; saying nothing about it would not be.
            Text(
                'No channel yet — this person cannot be messaged, and will not '
                'appear on an occasion run.',
                style: PT.secondary.copyWith(color: t.attention.text)),
          ],
          const SizedBox(height: PD.sectionGap),
          Text('OCCASIONS',
              style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          // The same warning the capture screen carries. It is the one piece
          // of guidance in this app that is about people rather than software.
          Text('Never guess religion. If unsure, tag only New Year.',
              style: PT.secondary.copyWith(color: t.textMuted)),
          const SizedBox(height: 8),
          ValueListenableBuilder<List<OccasionTagRow>>(
            valueListenable: TagVocab.all,
            builder: (context, _, _) {
              final vocab = TagVocab.live;
              final known = {for (final v in vocab) v.slug};
              // Slugs the person carries that the vocabulary has no row for.
              // Drawn so they can be seen and toggled off rather than sitting
              // invisibly on the record.
              final orphans = _tags.where((s) => !known.contains(s)).toList()
                ..sort();
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slug in [...vocab.map((v) => v.slug), ...orphans])
                    PhoneChip(
                      label: TagVocab.labelFor(slug),
                      selected: _tags.contains(slug),
                      onTap: () => setState(() {
                        _tags.contains(slug)
                            ? _tags.remove(slug)
                            : _tags.add(slug);
                      }),
                    ),
                  NewTagChip(
                      db: widget.db,
                      onCreated: (slug) => setState(() => _tags.add(slug))),
                ],
              );
            },
          ),
          const SizedBox(height: PD.sectionGap),
          PhoneField(label: 'Met where', controller: _metWhere),
          const SizedBox(height: PD.groupGap),
          // House date sheet, past-capped: meeting dates are past, so the
          // forward offset chips are nonsense here and the range ends today
          // (§3.3). The Material showDatePicker died with the v2 migration.
          PhoneDateRow(
            label: 'Met when',
            value: _metWhen ?? widget.person.metWhen ?? DateTime.now(),
            capPast: true,
            onChanged: (d) => setState(() => _metWhen = d),
          ),
          const SizedBox(height: PD.groupGap),
          PhoneField(label: 'Notes', controller: _notes),
          const SizedBox(height: PD.sectionGap),
          // Delete is admin: taken deliberately after reviewing the record,
          // never a third destructive icon in the nav bar.
          PhoneBtn('Delete person',
              variant: PhoneBtnVariant.danger, expand: true, onPressed: _delete),
        ],
        ),
      ),
    );
  }
}
