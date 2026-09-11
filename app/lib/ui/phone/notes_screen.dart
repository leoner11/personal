import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import 'phone_pickers.dart';
import 'phone_primitives.dart';

/// ⚠ DELIBERATELY MINIMAL, same as the Mac. A textarea. No rich editor, no
/// markdown preview, no backlinks, no full-text search. Building a good editor
/// costs more than the entire rest of this app.
///
/// ⚠ WHAT DOES NOT CARRY FROM THE MAC: it is a two-pane master-detail — a
/// 300pt list beside the editor, both always visible. At 390pt there is room
/// for one of those. The list is the screen; the editor is a near-full-height
/// sheet over it, which is also what keeps the editor from being a second
/// push deep from the Review tab.
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
    await PhoneSheet.show<void>(
      context,
      (_) => PhoneNoteEditor(db: widget.db, note: n),
    );
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

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return StreamBuilder<List<Note>>(
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

        return PhoneBody(
          title: 'Notes',
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _newNote,
            child: SizedBox(
              width: PD.tapMin,
              height: PD.tapMin,
              child: Icon(Icons.add, size: 26, color: t.accent),
            ),
          ),
          child: Column(
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
                          return PhoneRow(
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
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The editor. Body first and focused; everything else is below it.
///
/// ⚠ Autosave on pause, no save button — the same contract as the Mac, and it
/// matters more here because a sheet can be dismissed with a swipe at any
/// moment. [dispose] flushes, so a swipe-away never costs the last keystrokes.
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

  @override
  void initState() {
    super.initState();
    _personId = widget.note.personId;
    _engagementId = widget.note.engagementId;
    _editor.addListener(_onChanged);
    _tag.addListener(_onChanged);
    _loadNames();
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
    return PhoneSheet(
      title: 'Note',
      expand: true,
      actions: Row(
        children: [
          Expanded(
            child: PhoneBtn(
              'Delete',
              variant: PhoneBtnVariant.ghost,
              onPressed: _confirmDelete,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PhoneBtn(
              'Done',
              variant: PhoneBtnVariant.primary,
              onPressed: () async {
                await _flush();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
      child: ListView(
        children: [
          // The body is the point of the screen, so it is first and it is
          // where the cursor lands.
          Container(
            constraints: const BoxConstraints(minHeight: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(D.radiusPanel),
            ),
            child: TextField(
              controller: _editor,
              autofocus: widget.note.body.isEmpty,
              maxLines: null,
              style: PT.body.copyWith(color: t.textPrimary, height: 1.5),
              cursorColor: t.accent,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Write.',
              ),
            ),
          ),
          const SizedBox(height: PD.sectionGap),
          // ⚠ The tag is a free text field, not a pick from existing tags.
          // On the Mac the tag once came only from the active filter, and the
          // filter only listed tags that already existed — so the first tag
          // could never be created. Do not reintroduce that.
          PhoneField(label: 'Tag', controller: _tag, hint: 'content / thesis'),
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
              await _patch(const NotesCompanion(personId: Value(null)));
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
              await _patch(NotesCompanion(engagementId: Value(e.id)));
            },
            onClear: () async {
              setState(() {
                _engagementId = null;
                _projectName = null;
              });
              await _patch(const NotesCompanion(engagementId: Value(null)));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final t = AppTokens.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: t.canvas,
        title: Text(
          'Delete this note?',
          style: PT.entityName.copyWith(color: t.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              'Cancel',
              style: PT.body.copyWith(color: t.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              'Delete',
              style: PT.body.copyWith(color: t.danger.text),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // ⚠ Cancel the pending autosave first, or it resurrects the body onto a
    // row that was just soft-deleted.
    _debounce?.cancel();
    _dirty = false;
    await widget.db.softDeleteRow(widget.db.notes, widget.note.id);
    if (mounted) Navigator.pop(context);
  }
}
