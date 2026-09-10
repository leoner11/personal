import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/occasions.dart';
import '../../theme/tokens.dart';
import 'phone_primitives.dart';

/// A1 — Capture. The screen the app exists for, and the default tab.
///
/// ⚠ THE 10-SECOND BUDGET IS THE ACCEPTANCE CRITERION, NOT AN ASPIRATION.
/// Past ~10 seconds per person, logging stops happening by week three and the
/// app becomes a graveyard. Every decision here is bought against that budget:
///
///   - keyboard is already up on open, name field focused
///   - name + one channel is the only rule; nothing else blocks the save
///   - occasion chips stay ABOVE the fold — they cannot be backfilled
///   - everything else collapses behind ONE disclosure, not a second screen
///
/// ⚠ Do not add whitespace here to make it breathe. Every 8pt of extra gap is
/// a fraction of a scroll, and a scroll is a second. Airiness belongs on the
/// screens you read, not the one you write.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _name = TextEditingController();
  final _wa = TextEditingController();
  final _wechat = TextEditingController();
  final _company = TextEditingController();
  final _metWhere = TextEditingController();
  final _notes = TextEditingController();

  final _nameFocus = FocusNode();
  final _tags = <OccasionTag>{};
  bool _detail = false;
  bool _wechatMode = false;
  String? _justSaved;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _wa, _wechat]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _wa, _wechat, _company, _metWhere, _notes]) {
      c.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  /// Name plus at least one channel. The only rule in the app.
  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      (_wa.text.trim().isNotEmpty || _wechat.text.trim().isNotEmpty);

  Future<void> _save() async {
    if (!_canSave) return;
    final name = _name.text.trim();
    final wa = _wa.text.trim();
    final wechat = _wechat.text.trim();

    await widget.db.addPerson(PeopleCompanion.insert(
      name: name,
      company: Value(_blank(_company)),
      waNumber: Value(wa.isEmpty ? null : wa),
      wechatId: Value(wechat.isEmpty ? null : wechat),
      // Both filled defaults to WhatsApp — it is the one that deep-links.
      preferredChannel: Value(wa.isNotEmpty ? 'wa' : 'wechat'),
      metWhere: Value(_blank(_metWhere)),
      metWhen: Value(DateTime.now()),
      notes: Value(_blank(_notes)),
      occasionTags: Value(_tags.map((t) => t.name).toList()),
    ));

    if (!mounted) return;
    // ⚠ Clear and stay put rather than navigating away. Capture happens in
    // bursts — you meet three people at one mixer — and a success screen you
    // have to dismiss costs more than it reassures.
    setState(() {
      _justSaved = name;
      for (final c in [_name, _wa, _wechat, _company, _metWhere, _notes]) {
        c.clear();
      }
      _tags.clear();
      _detail = false;
    });
    _nameFocus.requestFocus();
  }

  String? _blank(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneBody(
      title: 'Capture',
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  PD.screenPad, 0, PD.screenPad, PD.sectionGap),
              children: [
                if (_justSaved != null) ...[
                  Row(children: [
                    PhoneTag(tone: t.success, label: 'Saved'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_justSaved!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PT.secondary.copyWith(color: t.textSecondary)),
                    ),
                  ]),
                  const SizedBox(height: PD.groupGap),
                ],

                PhoneField(
                  label: 'Name',
                  controller: _name,
                  hint: 'Pak Andi',
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: PD.groupGap),

                // One channel field at a time. Showing both doubles the
                // height of the only part of this form that is mandatory.
                Row(children: [
                  PhoneChip(
                      label: 'WhatsApp',
                      selected: !_wechatMode,
                      onTap: () => setState(() => _wechatMode = false)),
                  const SizedBox(width: 8),
                  PhoneChip(
                      label: 'WeChat',
                      selected: _wechatMode,
                      onTap: () => setState(() => _wechatMode = true)),
                ]),
                const SizedBox(height: 10),
                if (_wechatMode)
                  PhoneField(
                      label: 'WeChat ID',
                      controller: _wechat,
                      hint: 'wxid_...',
                      textCapitalization: TextCapitalization.none)
                else
                  PhoneField(
                      label: 'WhatsApp',
                      controller: _wa,
                      hint: '628123456789',
                      keyboardType: TextInputType.phone,
                      textCapitalization: TextCapitalization.none),

                const SizedBox(height: PD.sectionGap),

                // ⚠ ABOVE THE FOLD, DELIBERATELY. Flowchart A1-3: this is the
                // only field worth being slightly annoying about, because it
                // cannot be backfilled — you will not remember. Everything
                // else can hide; this cannot.
                Text('OCCASIONS',
                    style: PT.micro
                        .copyWith(color: t.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 4),
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
                        onTap: () => setState(() => _tags.contains(tag)
                            ? _tags.remove(tag)
                            : _tags.add(tag)),
                      ),
                  ],
                ),

                const SizedBox(height: PD.sectionGap),

                // ⚠ ONE disclosure for everything optional. Not a wizard, not
                // a second screen, not a stepper.
                GestureDetector(
                  onTap: () => setState(() => _detail = !_detail),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: PD.tapMin,
                    child: Row(children: [
                      Icon(
                          _detail
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          size: 20,
                          color: t.textSecondary),
                      const SizedBox(width: 4),
                      Text('Add detail',
                          style: PT.body.copyWith(color: t.textSecondary)),
                    ]),
                  ),
                ),
                if (_detail) ...[
                  PhoneField(
                      label: 'Company',
                      controller: _company,
                      hint: 'PT Formcase'),
                  const SizedBox(height: PD.groupGap),
                  PhoneField(
                      label: 'Met where',
                      controller: _metWhere,
                      hint: 'ZIBS mixer'),
                  const SizedBox(height: PD.groupGap),
                  PhoneField(
                      label: 'Notes',
                      controller: _notes,
                      hint: 'one line is fine'),
                ],
              ],
            ),
          ),

          // Pinned, full width, thumb-reachable without scrolling back up.
          Container(
            padding: const EdgeInsets.fromLTRB(
                PD.screenPad, 10, PD.screenPad, 10),
            decoration: BoxDecoration(
              color: t.canvas,
              border: Border(top: BorderSide(color: t.line)),
            ),
            child: SafeArea(
              top: false,
              child: PhoneBtn(
                'Save',
                variant: PhoneBtnVariant.primary,
                expand: true,
                onPressed: _canSave ? _save : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
