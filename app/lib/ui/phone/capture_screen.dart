import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/tag_vocab.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'occasion_tag_sheets.dart';
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
/// v2 modernizes the chrome only and adds ZERO taps to the path (P3): focus
/// rings on fields, press states on chips and Save, Next/Done on the keyboard
/// where Done SAVES when the form is valid (it subtracts a tap), and the
/// Saved tag pops in instead of appearing.
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
  final _model = _CaptureModel();

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _model.save(widget.db);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return AnimatedBuilder(
      animation: _model,
      builder: (context, _) => PhoneScaffold(
        title: 'Capture',
        // ⚠ No trailing nav-bar action — nothing here is worth a header trip;
        // the one action is pinned at the thumb (P2).
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    PD.screenPad, 0, PD.screenPad, PD.sectionGap),
                children: [
                  _CaptureForm(
                    db: widget.db,
                    model: _model,
                    showSavedTag: true,
                    onSubmittedLast: _save,
                  ),
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
                  onPressed: _model.canSave ? _save : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// People tab's + action (§7.6): the capture contract as a large sheet — name
/// + one channel, zero validation, occasion chips above the fold, metWhen =
/// now. Pops itself on save, so the new person lands in the list you came
/// from; no Saved tag in here because you have already left.
Future<void> showNewPersonSheet(BuildContext context, AppDatabase db) =>
    PhoneSheet.show<void>(context, (_) => _NewPersonSheet(db: db));

class _NewPersonSheet extends StatefulWidget {
  const _NewPersonSheet({required this.db});
  final AppDatabase db;

  @override
  State<_NewPersonSheet> createState() => _NewPersonSheetState();
}

class _NewPersonSheetState extends State<_NewPersonSheet> {
  final _model = _CaptureModel();

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await _model.save(widget.db);
    if (saved && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _model,
      builder: (context, _) => PhoneSheet(
        title: 'New person',
        expand: true,
        actions: PhoneBtn(
          'Save',
          variant: PhoneBtnVariant.primary,
          expand: true,
          onPressed: _model.canSave ? _save : null,
        ),
        child: SingleChildScrollView(
          child: _CaptureForm(
              db: widget.db, model: _model, onSubmittedLast: _save),
        ),
      ),
    );
  }
}

/// The write path and its state, owned once and shared by the tab and the
/// sheet — the one-channel rule must not drift between two hosts.
///
/// ⚠ Zero validation beyond name + one channel. No length checks, no phone
/// formatting, no uniqueness check: a half-known number captured now beats a
/// correct one captured never. That is the economics this screen exists for.
class _CaptureModel extends ChangeNotifier {
  final name = TextEditingController();
  final wa = TextEditingController();
  final wechat = TextEditingController();
  final company = TextEditingController();
  final metWhere = TextEditingController();
  final notes = TextEditingController();

  final nameFocus = FocusNode();
  final channelFocus = FocusNode();
  final companyFocus = FocusNode();
  final metWhereFocus = FocusNode();
  final notesFocus = FocusNode();

  /// Slugs from the occasion_tags table, not enum values.
  final tags = <String>{};
  bool detail = false;

  /// One channel field at a time. Showing both doubles the height of the
  /// only part of this form that is mandatory.
  bool wechatMode = false;

  /// The previous person, for the Saved tag. Survives until the next save —
  /// capture happens in bursts, and the tag is the receipt of the last one.
  String? justSaved;

  _CaptureModel() {
    for (final c in [name, wa, wechat]) {
      c.addListener(notifyListeners);
    }
  }

  /// Name plus at least one channel. The only rule in the app.
  bool get canSave =>
      name.text.trim().isNotEmpty &&
      (wa.text.trim().isNotEmpty || wechat.text.trim().isNotEmpty);

  /// Returns true when a person was written.
  Future<bool> save(AppDatabase db) async {
    if (!canSave) return false;
    final savedName = name.text.trim();
    final waText = wa.text.trim();
    final wechatText = wechat.text.trim();

    await db.addPerson(PeopleCompanion.insert(
      name: savedName,
      company: Value(_blank(company)),
      waNumber: Value(waText.isEmpty ? null : waText),
      wechatId: Value(wechatText.isEmpty ? null : wechatText),
      // Both filled defaults to WhatsApp — it is the one that deep-links.
      preferredChannel: Value(waText.isNotEmpty ? 'wa' : 'wechat'),
      metWhere: Value(_blank(metWhere)),
      metWhen: Value(DateTime.now()),
      notes: Value(_blank(notes)),
      occasionTags: Value(tags.toList()),
    ));

    // ⚠ Clear and stay put rather than navigating away. You meet three
    // people at one mixer — a success screen you have to dismiss costs more
    // than it reassures.
    justSaved = savedName;
    for (final c in [name, wa, wechat, company, metWhere, notes]) {
      c.clear();
    }
    tags.clear();
    detail = false;
    notifyListeners();
    nameFocus.requestFocus();
    return true;
  }

  String? _blank(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// ⚠ Mutations go through these, never bare field writes — the hosts
  /// listen to this ChangeNotifier, and a silent write would leave the
  /// pinned Save button stale.
  void setChannel(bool wechat) {
    wechatMode = wechat;
    notifyListeners();
  }

  void toggleTag(String tag) {
    tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
    notifyListeners();
  }

  void toggleDetail() {
    detail = !detail;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final c in [name, wa, wechat, company, metWhere, notes]) {
      c.dispose();
    }
    for (final f in [
      nameFocus,
      channelFocus,
      companyFocus,
      metWhereFocus,
      notesFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }
}

/// The form itself: saved-tag row → Name → channel chips + one channel field
/// → OCCASIONS + helper + 8 chips → Add detail → Company / Met where / Notes.
/// ⚠ Everything above the disclosure is FROZEN (§6 layout) — this is the
/// 10-second path; reorder nothing.
class _CaptureForm extends StatelessWidget {
  const _CaptureForm({
    required this.db,
    required this.model,
    required this.onSubmittedLast,
    this.showSavedTag = false,
  });

  /// Only for the 'New tag' chip — the model still takes its db at save().
  final AppDatabase db;
  final _CaptureModel model;
  final VoidCallback onSubmittedLast;

  /// The tab renders the Saved row (you stay put and see it); the sheet pops
  /// on save, so the tag would never be read there.
  final bool showSavedTag;

  /// Done on the LAST visible field saves when valid — the one keyboard
  /// change that touches the path, and it subtracts a tap (§6 Capture).
  void _done() {
    if (model.canSave) onSubmittedLast();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final last = model.detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSavedTag && model.justSaved != null) ...[
          // The pop replays per save: a fresh key restarts the tween — the
          // same trick PhoneChip uses for its selection pop (§3.6).
          TweenAnimationBuilder<double>(
            key: ValueKey(model.justSaved),
            tween: Tween(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 340),
            curve: PM.pop,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Row(children: [
              PhoneTag(tone: t.success, label: 'Saved'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(model.justSaved!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        PT.secondary.copyWith(color: t.textSecondary)),
              ),
            ]),
          ),
          const SizedBox(height: PD.groupGap),
        ],

        PhoneField(
          label: 'Name',
          controller: model.name,
          focusNode: model.nameFocus,
          hint: 'Pak Andi',
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: PD.groupGap),

        Row(children: [
          PhoneChip(
              label: 'WhatsApp',
              selected: !model.wechatMode,
              onTap: () => model.setChannel(false)),
          const SizedBox(width: 8),
          PhoneChip(
              label: 'WeChat',
              selected: model.wechatMode,
              onTap: () => model.setChannel(true)),
        ]),
        const SizedBox(height: 10),
        if (model.wechatMode)
          PhoneField(
              label: 'WeChat ID',
              controller: model.wechat,
              focusNode: model.channelFocus,
              hint: 'wxid_...',
              textCapitalization: TextCapitalization.none,
              textInputAction:
                  last ? TextInputAction.done : TextInputAction.next,
              onSubmitted: last ? (_) => _done() : null)
        else
          PhoneField(
              label: 'WhatsApp',
              controller: model.wa,
              focusNode: model.channelFocus,
              hint: '628123456789',
              keyboardType: TextInputType.phone,
              textCapitalization: TextCapitalization.none,
              textInputAction:
                  last ? TextInputAction.done : TextInputAction.next,
              onSubmitted: last ? (_) => _done() : null),

        const SizedBox(height: PD.sectionGap),

        // ⚠ ABOVE THE FOLD, DELIBERATELY. Flowchart A1-3: this is the only
        // field worth being slightly annoying about, because it cannot be
        // backfilled — you will not remember. Everything else can hide; this
        // cannot.
        Text('OCCASIONS',
            style:
                PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text('Never guess religion. If unsure, tag only New Year.',
            style: PT.secondary.copyWith(color: t.textMuted)),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<OccasionTagRow>>(
          valueListenable: TagVocab.all,
          builder: (context, _, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in TagVocab.live)
                PhoneChip(
                  label: tag.label,
                  selected: model.tags.contains(tag.slug),
                  onTap: () => model.toggleTag(tag.slug),
                ),
              // ⚠ Adding a tag has to be possible from HERE. The moment you
              // discover the vocabulary is short is the moment you are tagging
              // someone; sending them to a settings screen mid-capture is how
              // the 10-second budget dies.
              NewTagChip(
                  db: db, onCreated: model.toggleTag),
            ],
          ),
        ),

        const SizedBox(height: PD.sectionGap),

        // ⚠ ONE disclosure for everything optional. Not a wizard, not a
        // second screen, not a stepper.
        PhonePressable(
          onTap: model.toggleDetail,
          child: SizedBox(
            height: PD.tapMin,
            child: Row(children: [
              AppIcon(
                  model.detail ? Ic.chevronDown : Ic.chevronRight,
                  size: 20,
                  color: t.textSecondary),
              const SizedBox(width: 4),
              Text('Add detail',
                  style: PT.body.copyWith(color: t.textSecondary)),
            ]),
          ),
        ),
        if (model.detail) ...[
          PhoneField(
              label: 'Company',
              controller: model.company,
              focusNode: model.companyFocus,
              hint: 'PT Formcase',
              textInputAction: TextInputAction.next),
          const SizedBox(height: PD.groupGap),
          PhoneField(
              label: 'Met where',
              controller: model.metWhere,
              focusNode: model.metWhereFocus,
              hint: 'ZIBS mixer',
              textInputAction: TextInputAction.next),
          const SizedBox(height: PD.groupGap),
          PhoneField(
              label: 'Notes',
              controller: model.notes,
              focusNode: model.notesFocus,
              hint: 'one line is fine',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _done()),
        ],
      ],
    );
  }
}
