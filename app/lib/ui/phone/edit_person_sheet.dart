import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/occasions.dart';
import '../../theme/tokens.dart';
import 'phone_primitives.dart';

/// Editing a person on the phone.
///
/// ⚠ WHY THIS EXISTS. Until it did, the only write either shell could perform
/// on a person was a soft delete — so a wrong number, a misspelt name or a
/// missing occasion tag was permanent. `money`, `notes` and `engagements` all
/// had an update path; `people`, the table the app exists for, did not.
///
/// ⚠ A SHEET, NOT A PUSH. Person detail is already one push from the People
/// tab, and the design spec allows nothing more than one push deep.
///
/// ⚠ EDITING IS LOOSER THAN CAPTURING. Capture demands a channel because you
/// are in front of the person and have it. Editing is usually admin — adding a
/// tag weeks later — and demanding a number you do not have would strand the
/// row. So this saves without one, and says so where you can see it.
class PhoneEditPersonSheet extends StatefulWidget {
  const PhoneEditPersonSheet({super.key, required this.db, required this.person});
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
  late final _notes = TextEditingController(text: widget.person.notes ?? '');
  final _tags = <OccasionTag>{};

  @override
  void initState() {
    super.initState();
    for (final id in widget.person.occasionTags) {
      final tag = OccasionTag.fromId(id);
      // ⚠ Skip rather than crash on a tag this build does not know — a row
      // synced from a newer client must not make its person uneditable.
      if (tag != null) _tags.add(tag);
    }
    for (final c in [_name, _wa, _wechat]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _company, _wa, _wechat, _notes]) {
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
    await widget.db.updatePerson(
      widget.person.id,
      PeopleCompanion(
        name: Value(_name.text.trim()),
        company: Value(_company.text.trim().isEmpty ? null : _company.text.trim()),
        waNumber: Value(wa.isEmpty ? null : wa),
        wechatId: Value(wechat.isEmpty ? null : wechat),
        preferredChannel: Value(_preferred),
        // ⚠ metWhen untouched — it records when you met, not when you last
        // edited the row.
        notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
        occasionTags: Value(_tags.map((t) => t.name).toList()),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneSheet(
      title: 'Edit person',
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in OccasionTag.values)
                PhoneChip(
                  label: tag.label,
                  selected: _tags.contains(tag),
                  onTap: () => setState(() {
                    _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag);
                  }),
                ),
            ],
          ),
          const SizedBox(height: PD.sectionGap),
          PhoneField(label: 'Notes', controller: _notes),
        ],
      ),
    );
  }
}
