import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'phone_pickers.dart';
import 'phone_primitives.dart';

/// ⚠ DELIBERATELY MINIMAL, same as the Mac. A textarea. No rich editor, no
/// markdown preview, no backlinks, no full-text search. Building a good editor
/// costs more than the entire rest of this app.
///
/// ⚠ WHAT DOES NOT CARRY FROM THE MAC: it is a two-pane master-detail — a
/// 300pt list beside the editor, both always visible. At 390pt there is room
/// for one of those. The list is the screen; the editor is a full-screen
/// push over it (session 2) — one push deep from the Review tab, which is
/// the ceiling the design allows and the right amount of chrome for writing.
///
/// v2: delete becomes a trailing swipe on the list rows — the one Review
/// surface where delete is a frequent maintenance gesture on a homogeneous
/// list, which is exactly §3.2's "swipe where frequent". It still confirms,
/// and it still only soft deletes.
class PhoneNotesScreen extends StatefulWidget {
  const PhoneNotesScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<PhoneNotesScreen> createState() => _PhoneNotesScreenState();
}

class _PhoneNotesScreenState extends State<PhoneNotesScreen> {
  String? _tagFilter;
  Map<String, Person> _people = {};
  Map<String, Engagement> _projects = {};

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final p = await widget.db.peopleById();
    final e = await widget.db.engagementsById();
    if (mounted) {
      setState(() {
        _people = p;
        _projects = e;
      });
    }
  }

  Future<void> _open(Note n) async {
    // Full-screen push (session 2) — writing is a page, not a detent.
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PhoneNoteEditor(db: widget.db, note: n),
    ));
    if (mounted) _loadLookups();
  }

  Future<void> _newNote() async {
    // Generate the id here: insert() returns a rowid, not the text key.
    final id = newId();
    await widget.db
        .into(widget.db.notes)
        .insert(
          NotesCompanion.insert(
            id: Value(id),
            date: DateTime.now(),
            // Inherits the active filter, so writing three 'thesis' notes in a
            // row does not mean tagging each one.
            tag: Value(_tagFilter),
          ),
        );
    final fresh = await widget.db.watchNotes().first;
    final match = fresh.where((n) => n.id == id);
    if (match.isEmpty || !mounted) return;
    await _open(match.first);
  }

  /// Trailing swipe → the house confirm → soft delete. The light haptic is
  /// the swipe firing (§3.4); the warning haptic comes from the confirm.
  Future<bool> _swipeToDelete(Note n) async {
    PhoneHaptic.light();
    final ok = await showPhoneConfirm(
      context,
      title: 'Delete this note?',
      body: 'The note is kept so the other device learns it is gone.',
    );
    if (!ok) return false;
    await widget.db.softDeleteRow(widget.db.notes, n.id);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneScaffold(
      title: 'Notes',
      actions: [
        PhonePressable(
          onTap: _newNote,
          pressedScale: 0.9,
          child: SizedBox(
            width: PD.tapMin,
            height: PD.tapMin,
            child: Center(child: AppIcon(Ic.add, size: 26, color: t.accent)),
          ),
        ),
      ],
      child: StreamBuilder<List<Note>>(
        stream: widget.db.watchNotes(),
        builder: (context, snap) {
          final all = snap.data ?? const <Note>[];
          final tags = {
            for (final n in all)
              if (n.tag != null && n.tag!.isNotEmpty) n.tag!,
          }.toList()..sort();
          final rows = _tagFilter == null
              ? all
              : all.where((n) => n.tag == _tagFilter).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hidden entirely until a tag exists — a filter row offering
              // only "all" is furniture.
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PD.screenPad,
                    0,
                    PD.screenPad,
                    PD.groupGap,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PhoneChip(
                        label: 'all',
                        selected: _tagFilter == null,
                        onTap: () => setState(() => _tagFilter = null),
                      ),
                      for (final tg in tags)
                        PhoneChip(
                          label: tg,
                          selected: _tagFilter == tg,
                          onTap: () => setState(() => _tagFilter = tg),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: rows.isEmpty
                    ? const PhoneEmpty('No notes.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          PD.screenPad,
                          0,
                          PD.screenPad,
                          PD.sectionGap,
                        ),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const PhoneDivider(),
                        itemBuilder: (_, i) {
                          final n = rows[i];
                          final first = n.body.split('\n').first;
                          return Dismissible(
                            key: ValueKey(n.id),
                            direction: DismissDirection.endToStart,
                            background: PhoneSwipeBackground(
                              label: 'Delete',
                              icon: Ic.dismiss,
                              color: t.danger.wash,
                            ),
                            confirmDismiss: (_) => _swipeToDelete(n),
                            child: PhoneRow(
                              title: first.isEmpty ? 'untitled' : first,
                              subtitle: [
                                fmtDate(n.date),
                                if (n.tag != null && n.tag!.isNotEmpty) n.tag!,
                                if (_people[n.personId] != null)
                                  _people[n.personId]!.name,
                                if (_projects[n.engagementId] != null)
                                  _projects[n.engagementId]!.name,
                              ].join(' · '),
                              chevron: true,
                              onTap: () => _open(n),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The editor — a FULL-SCREEN PUSH (session 2), not a sheet. The text area
/// IS the page: edge-to-edge, grows unbounded, no box border. The old
/// near-full-height sheet boxed the textarea among TAG/DATE/PERSON/PROJECT
/// rows and read as editing settings, not writing; the metadata now
/// collapses into a Details disclosure under the text, and Delete lives
/// inside it behind the house confirm. Back chevron and Done both flush.
///
/// ⚠ Autosave on pause, no save button — the same contract as the Mac.
/// [dispose] still flushes, so even the swipe-back never costs the last
/// keystrokes.
class PhoneNoteEditor extends StatefulWidget {
  const PhoneNoteEditor({super.key, required this.db, required this.note});
  final AppDatabase db;
  final Note note;

  @override
  State<PhoneNoteEditor> createState() => _PhoneNoteEditorState();
}

class _PhoneNoteEditorState extends State<PhoneNoteEditor> {
  late final _editor = TextEditingController(text: widget.note.body);
  late final _tag = TextEditingController(text: widget.note.tag ?? '');
  late DateTime _date = widget.note.date;
  String? _personId;
  String? _engagementId;
  String? _personName;
  String? _projectName;
  Timer? _debounce;
  bool _dirty = false;
  bool _detailsOpen = false;

  @override
  void initState() {
    super.initState();
    _personId = widget.note.personId;
    _engagementId = widget.note.engagementId;
    _editor.addListener(_onChanged);
    _tag.addListener(_onChanged);
    // The Details summary shows the tag live; the autosave listener above
    // deliberately never rebuilds.
    _tag.addListener(_refreshSummary);
    _loadNames();
  }

  void _refreshSummary() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNames() async {
    final people = await widget.db.peopleById();
    final projects = await widget.db.engagementsById();
    if (!mounted) return;
    setState(() {
      _personName = people[_personId]?.name;
      _projectName = projects[_engagementId]?.name;
    });
  }

  void _onChanged() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
  }

  Future<void> _flush() async {
    if (!_dirty) return;
    _dirty = false;
    final tag = _tag.text.trim();
    await widget.db.updateNote(
      widget.note.id,
      NotesCompanion(
        body: Value(_editor.text),
        tag: Value(tag.isEmpty ? null : tag),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // ⚠ Fire-and-forget on purpose: dispose cannot await, and the write is
    // already queued on the database. Dropping it here would mean a swipe
    // dismiss silently loses whatever was typed in the last 600ms.
    unawaited(_flush());
    _editor.dispose();
    _tag.dispose();
    super.dispose();
  }

  Future<void> _patch(NotesCompanion patch) => widget.db.updateNote(
    widget.note.id,
    patch.copyWith(updatedAt: Value(DateTime.now())),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.canvas,
      // ⚠ resizeToAvoidBottomInset (the default) is the keyboard handling:
      // the body shrinks and the Details strip rides above the keyboard.
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: PD.tapMin,
              child: Row(children: [
                PhonePressable(
                  onTap: _exit,
                  pressedScale: 0.9,
                  child: SizedBox(
                    width: PD.tapMin,
                    height: PD.tapMin,
                    child: Center(
                      child: AppIcon(
                          Ic.chevronLeft, size: 24, color: t.accent),
                    ),
                  ),
                ),
                const Spacer(),
                PhonePressable(
                  onTap: _exit,
                  pressedScale: 0.94,
                  child: SizedBox(
                    height: PD.tapMin,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: PD.screenPad),
                        child: Text('Done',
                            style: PT.body.copyWith(
                                color: t.accent,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            // Hairline under the bar; the page reads as one sheet of paper.
            Container(height: 1, color: t.line),
            // ⚠ THE PAGE. Edge-to-edge, unbounded, no box — the text area is
            // the screen, not one field among five.
            Expanded(
              child: TextField(
                controller: _editor,
                autofocus: widget.note.body.isEmpty,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style:
                    PT.body.copyWith(color: t.textPrimary, height: 1.5),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.fromLTRB(
                    PD.screenPad,
                    PD.groupGap,
                    PD.screenPad,
                    PD.sectionGap,
                  ),
                  hintText: 'Write.',
                  hintStyle: PT.body.copyWith(color: t.textMuted),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: PM.clearMs),
              curve: Curves.ease,
              alignment: Alignment.bottomCenter,
              child: _detailsStrip(t),
            ),
          ],
        ),
      ),
    );
  }

  /// Both explicit exits flush before popping; [dispose] still covers the
  /// swipe-back. No save button — autosave on pause is the whole contract.
  Future<void> _exit() async {
    await _flush();
    if (mounted) Navigator.pop(context);
  }

  /// Metadata, collapsed by default: one 44pt row saying what is set.
  /// Opening it drops Tag/Date/Person/Project and Delete into the space
  /// below the text — editing settings is a state, never the page.
  Widget _detailsStrip(AppTokens t) {
    // The date is always set, so the summary always says something.
    final summary = [
      if (_tag.text.trim().isNotEmpty) _tag.text.trim(),
      fmtDate(_date),
      ?_personName,
      ?_projectName,
    ].join(' · ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: t.line),
        PhonePressable(
          onTap: () => setState(() => _detailsOpen = !_detailsOpen),
          child: SizedBox(
            height: PD.tapMin,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: PD.screenPad),
              child: Row(children: [
                Text('Details',
                    style: PT.body.copyWith(
                        color: t.textSecondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PT.secondary.copyWith(color: t.textMuted)),
                ),
                const SizedBox(width: 6),
                AppIcon(Ic.chevronDown, size: 20, color: t.textMuted),
              ]),
            ),
          ),
        ),
        if (_detailsOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(PD.screenPad, PD.groupGap,
                PD.screenPad, PD.sectionGap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⚠ The tag is a free text field, not a pick from existing
                // tags — the Mac once shipped that trap and the first tag
                // could never be created. Do not reintroduce it.
                PhoneField(
                  label: 'Tag',
                  controller: _tag,
                  hint: 'content / thesis',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: PD.groupGap),
                PhoneDateRow(
                  label: 'Date',
                  value: _date,
                  onChanged: (d) {
                    setState(() => _date = d);
                    _patch(NotesCompanion(date: Value(d)));
                  },
                ),
                const SizedBox(height: PD.groupGap),
                PhoneLinkRow(
                  label: 'Person',
                  value: _personName,
                  onTap: () async {
                    final p = await pickPerson(context, widget.db);
                    if (p == null) return;
                    setState(() {
                      _personId = p.id;
                      _personName = p.name;
                    });
                    await _patch(NotesCompanion(personId: Value(p.id)));
                  },
                  onClear: () async {
                    setState(() {
                      _personId = null;
                      _personName = null;
                    });
                    await _patch(
                        const NotesCompanion(personId: Value(null)));
                  },
                ),
                const SizedBox(height: PD.groupGap),
                PhoneLinkRow(
                  label: 'Project',
                  value: _projectName,
                  onTap: () async {
                    final e = await pickProject(context, widget.db);
                    if (e == null) return;
                    setState(() {
                      _engagementId = e.id;
                      _projectName = e.name;
                    });
                    await _patch(
                        NotesCompanion(engagementId: Value(e.id)));
                  },
                  onClear: () async {
                    setState(() {
                      _engagementId = null;
                      _projectName = null;
                    });
                    await _patch(const NotesCompanion(
                        engagementId: Value(null)));
                  },
                ),
                const SizedBox(height: PD.sectionGap),
                // The house confirm owns destruction (§3.3); this button
                // only opens it. Soft delete underneath.
                PhoneBtn('Delete note',
                    variant: PhoneBtnVariant.danger,
                    expand: true,
                    onPressed: _confirmDelete),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showPhoneConfirm(
      context,
      title: 'Delete this note?',
      body: 'The note is kept so the other device learns it is gone.',
    );
    if (!ok) return;
    // ⚠ Cancel the pending autosave first, or it resurrects the body onto a
    // row that was just soft-deleted.
    _debounce?.cancel();
    _dirty = false;
    await widget.db.softDeleteRow(widget.db.notes, widget.note.id);
    if (mounted) Navigator.pop(context);
  }
}
