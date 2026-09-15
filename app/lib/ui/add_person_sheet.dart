import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/database.dart';
import '../domain/occasions.dart';
import '../theme/tokens.dart';
import 'platform.dart';
import 'widgets/primitives.dart';

/// A1 — Add Person, and editing one. ⚠ If logging a person takes more than ~10
/// seconds it stops happening by week three and the app becomes a graveyard.
/// Optimised for speed of entry, not completeness. Name plus one channel is all
/// that is required, and nothing else blocks the save.
///
/// ⚠ EDITING IS SLIGHTLY LOOSER THAN CAPTURING, on purpose. Capture demands a
/// channel because you are sitting in front of the person and have it. Editing
/// is often admin — adding an occasion tag weeks later — and demanding a number
/// you do not have would strand the row entirely. So an edit may be saved
/// without a channel, and says so where you can see it.
class AddPersonSheet extends StatefulWidget {
  const AddPersonSheet(
      {super.key, required this.db, this.presetTag, this.existing});
  final AppDatabase db;
  final OccasionTag? presetTag;

  /// Non-null puts the sheet in edit mode.
  final Person? existing;

  static Future<bool?> show(BuildContext context, AppDatabase db,
          {OccasionTag? presetTag, Person? existing}) =>
      showDialog<bool>(
        context: context,
        builder: (_) =>
            AddPersonSheet(db: db, presetTag: presetTag, existing: existing),
      );

  @override
  State<AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<AddPersonSheet> {
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _wa = TextEditingController();
  final _wechat = TextEditingController();
  final _metWhere = TextEditingController();
  final _notes = TextEditingController();
  final _pingNote = TextEditingController();

  final _tags = <OccasionTag>{};
  DateTime? _pingDate;
  String? _pingLabel;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _company.text = e.company ?? '';
      _wa.text = e.waNumber ?? '';
      _wechat.text = e.wechatId ?? '';
      _metWhere.text = e.metWhere ?? '';
      _notes.text = e.notes ?? '';
      _pingNote.text = e.pingNote ?? '';
      _pingDate = e.pingDate;
      for (final id in e.occasionTags) {
        final tag = OccasionTag.fromId(id);
        // ⚠ Skip rather than crash on a tag this build no longer knows. A row
        // synced from a newer client must not make its person uneditable.
        if (tag != null) _tags.add(tag);
      }
    }
    if (widget.presetTag != null) _tags.add(widget.presetTag!);
    _name.addListener(() => setState(() {}));
    _wa.addListener(() => setState(() {}));
    _wechat.addListener(() => setState(() {}));
  }

  bool get _hasChannel =>
      _wa.text.trim().isNotEmpty || _wechat.text.trim().isNotEmpty;

  // Name plus at least one channel — the only rule in the app. ⚠ Relaxed to
  // name-only when editing; see the class comment.
  bool get _canSave =>
      _name.text.trim().isNotEmpty && (_editing || _hasChannel);

  void _setPing(String label, int months) {
    setState(() {
      if (_pingLabel == label) {
        _pingLabel = null;
        _pingDate = null;
      } else {
        _pingLabel = label;
        final n = DateTime.now();
        _pingDate = DateTime(n.year, n.month + months, n.day);
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final wa = _wa.text.trim();
    final wechat = _wechat.text.trim();

    if (_editing) {
      await widget.db.updatePerson(
        widget.existing!.id,
        PeopleCompanion(
          name: Value(_name.text.trim()),
          company: Value(_company.text.trim().isEmpty ? null : _company.text.trim()),
          waNumber: Value(wa.isEmpty ? null : wa),
          wechatId: Value(wechat.isEmpty ? null : wechat),
          // ⚠ Keep the existing preference when both channels are present, so
          // editing a note does not silently switch someone from WeChat to
          // WhatsApp. Only fall back when the preferred one was cleared.
          preferredChannel: Value(_preferredOnEdit(wa, wechat)),
          metWhere:
              Value(_metWhere.text.trim().isEmpty ? null : _metWhere.text.trim()),
          // ⚠ metWhen is NOT touched. It records when you met, not when you
          // last edited the row.
          notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
          occasionTags: Value(_tags.map((t) => t.name).toList()),
          pingDate: Value(_pingDate),
          pingNote:
              Value(_pingNote.text.trim().isEmpty ? null : _pingNote.text.trim()),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    await widget.db.addPerson(PeopleCompanion.insert(
      name: _name.text.trim(),
      company: Value(_company.text.trim().isEmpty ? null : _company.text.trim()),
      waNumber: Value(wa.isEmpty ? null : wa),
      wechatId: Value(wechat.isEmpty ? null : wechat),
      // Both filled defaults to WhatsApp — it is the one that deep-links.
      preferredChannel: Value(wa.isNotEmpty ? 'wa' : 'wechat'),
      metWhere:
          Value(_metWhere.text.trim().isEmpty ? null : _metWhere.text.trim()),
      metWhen: Value(DateTime.now()),
      notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
      occasionTags: Value(_tags.map((t) => t.name).toList()),
      pingDate: Value(_pingDate),
      pingNote:
          Value(_pingNote.text.trim().isEmpty ? null : _pingNote.text.trim()),
    ));
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Keeps the stored preference when it is still reachable.
  String _preferredOnEdit(String wa, String wechat) {
    final current = widget.existing!.preferredChannel;
    if (current == 'wa' && wa.isNotEmpty) return 'wa';
    if (current == 'wechat' && wechat.isNotEmpty) return 'wechat';
    return wa.isNotEmpty ? 'wa' : 'wechat';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: CallbackShortcuts(
        bindings: {
          // ⌘⏎ (Ctrl+Enter on Windows) confirms the primary action in a sheet.
          cmd(LogicalKeyboardKey.enter): _save,
        },
        child: Focus(
          autofocus: true,
          child: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_editing ? 'Edit person' : 'Add person',
                      style: T.screenTitle.copyWith(color: t.textPrimary)),
                  const SizedBox(height: 16),

                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Field(
                            label: 'Name',
                            controller: _name,
                            autofocus: true,
                            hint: 'Pak Andi')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Field(
                            label: 'Company',
                            controller: _company,
                            hint: 'PT Formcase')),
                  ]),
                  const SizedBox(height: 12),

                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Field(
                            label: 'WhatsApp',
                            controller: _wa,
                            hint: '628123456789')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Field(
                            label: 'WeChat ID',
                            controller: _wechat,
                            hint: 'wxid_...')),
                  ]),
                  const SizedBox(height: 4),
                  Text('One of the two is enough. Everything else is optional.',
                      style: T.secondary.copyWith(color: t.textMuted)),

                  const SizedBox(height: 16),
                  Text('OCCASIONS',
                      style: T.micro
                          .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(
                      'Cannot be backfilled later — you will not remember. '
                      'If unsure, tag only New Year. Never guess religion.',
                      style: T.secondary.copyWith(color: t.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in OccasionTag.values)
                        TagChip(
                          label: tag.label,
                          selected: _tags.contains(tag),
                          onTap: () => setState(() => _tags.contains(tag)
                              ? _tags.remove(tag)
                              : _tags.add(tag)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Field(
                            label: 'Met where',
                            controller: _metWhere,
                            hint: 'ZIBS mixer')),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Field(
                            label: 'Notes',
                            controller: _notes,
                            hint: 'one line is fine')),
                  ]),

                  const SizedBox(height: 16),
                  Text('PING ME LATER',
                      style: T.micro
                          .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    for (final (label, months) in const [
                      ('1 mo', 1),
                      ('3 mo', 3),
                      ('6 mo', 6),
                      ('12 mo', 12)
                    ])
                      TagChip(
                          label: label,
                          selected: _pingLabel == label,
                          onTap: () => _setPing(label, months)),
                  ]),
                  if (_pingDate != null) ...[
                    const SizedBox(height: 8),
                    Field(
                        label: 'Ping note',
                        controller: _pingNote,
                        hint: 'follow up on the gudang project'),
                    const SizedBox(height: 4),
                    Text(
                        'The note matters more than the date. A ping that fires '
                        'with no context is a ping you dismiss.',
                        style: T.secondary.copyWith(color: t.textMuted)),
                  ],

                  // ⚠ Visible, not silent. A person with no channel cannot be
                  // messaged, which is the point of the record — saying so is
                  // the price of letting the edit through at all.
                  if (_editing && !_hasChannel) ...[
                    const SizedBox(height: 12),
                    Text(
                        'No channel yet — this person cannot be messaged, and '
                        'will not appear on an occasion run.',
                        style: T.secondary.copyWith(color: t.attention.text)),
                  ],

                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Btn('Cancel',
                        variant: BtnVariant.ghost,
                        onPressed: () => Navigator.of(context).pop(false)),
                    const SizedBox(width: 8),
                    Btn('Save',
                        variant: BtnVariant.primary,
                        onPressed: _canSave ? _save : null),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
