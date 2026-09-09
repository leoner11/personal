import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/money_fmt.dart';
import '../../theme/tokens.dart';
import '../shell.dart';
import '../widgets/pickers.dart';
import '../widgets/primitives.dart';

/// ⚠ DELIBERATELY MINIMAL. A textarea and a save button. No rich editor, no
/// markdown preview, no backlinks, no full-text search in v1. Building a good
/// editor costs more than the entire rest of this app. Ship the textarea, feel
/// the pain first.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String? _selectedId;
  String? _tagFilter;
  final _editor = TextEditingController();
  Timer? _debounce;
  String? _loadedFor;
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

  @override
  void dispose() {
    _debounce?.cancel();
    _editor.dispose();
    super.dispose();
  }

  /// Autosave on pause. No save button to forget.
  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (_selectedId != null) widget.db.saveNote(_selectedId!, v);
    });
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
            if (n.tag != null && n.tag!.isNotEmpty) n.tag!
        }.toList()
          ..sort();
        final rows = _tagFilter == null
            ? all
            : all.where((n) => n.tag == _tagFilter).toList();
        final sel = rows.any((n) => n.id == _selectedId)
            ? rows.firstWhere((n) => n.id == _selectedId)
            : null;

        // Load the editor once per selection, not on every rebuild, or
        // typing fights the stream.
        if (sel != null && _loadedFor != sel.id) {
          _loadedFor = sel.id;
          _editor.text = sel.body;
        }

        return Row(children: [
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: t.card,
              border: Border(right: BorderSide(color: t.line)),
            ),
            child: Column(children: [
              const SizedBox(height: 38),
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    TagChip(
                        label: 'all',
                        selected: _tagFilter == null,
                        onTap: () => setState(() => _tagFilter = null)),
                    for (final tg in tags)
                      TagChip(
                          label: tg,
                          selected: _tagFilter == tg,
                          onTap: () => setState(() => _tagFilter = tg)),
                  ]),
                ),
              Expanded(
                child: rows.isEmpty
                    ? const EmptyLine('No notes.')
                    : ListView(children: [
                        for (final n in rows)
                          GestureDetector(
                            onTap: () => setState(() => _selectedId = n.id),
                            child: Container(
                              height: D.listRowTwoLine,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: n.id == _selectedId
                                    ? t.accentWash
                                    : Colors.transparent,
                                border: n.id == _selectedId
                                    ? Border(
                                        left: BorderSide(
                                            color: t.accent, width: 2))
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      n.body.split('\n').first.isEmpty
                                          ? 'untitled'
                                          : n.body.split('\n').first,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.body.copyWith(
                                          color: t.textPrimary,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                      [
                                        fmtDate(n.date),
                                        if (n.tag != null && n.tag!.isNotEmpty)
                                          n.tag!,
                                        if (_people[n.personId] != null)
                                          _people[n.personId]!.name,
                                        if (_projects[n.engagementId] != null)
                                          _projects[n.engagementId]!.name,
                                      ].join(' · '),
                                      style: T.secondary
                                          .copyWith(color: t.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                      ]),
              ),
            ]),
          ),
          Expanded(
            child: ScreenBody(
              title: 'Notes',
              trailing: Btn('New note',
                  variant: BtnVariant.primary,
                  onPressed: () async {
                    // Generate the id here: insert() returns a rowid, not
                    // the text primary key.
                    final id = newId();
                    await widget.db
                        .into(widget.db.notes)
                        .insert(NotesCompanion.insert(
                          id: Value(id),
                          date: DateTime.now(),
                          tag: Value(_tagFilter),
                        ));
                    setState(() => _selectedId = id);
                  }),
              child: sel == null
                  ? const EmptyLine('Select a note.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Panel(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: LinkBar(
                            db: widget.db,
                            personName: _people[sel.personId]?.name,
                            projectName: _projects[sel.engagementId]?.name,
                            onPerson: (p) async {
                              await widget.db.updateNote(
                                  sel.id,
                                  NotesCompanion(
                                      personId: Value(p?.id),
                                      updatedAt: Value(DateTime.now())));
                              await _loadLookups();
                            },
                            onProject: (e) async {
                              await widget.db.updateNote(
                                  sel.id,
                                  NotesCompanion(
                                      engagementId: Value(e?.id),
                                      updatedAt: Value(DateTime.now())));
                              await _loadLookups();
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Panel(
                      child: TextField(
                        controller: _editor,
                        onChanged: _onChanged,
                        maxLines: null,
                        expands: false,
                        style: T.body.copyWith(color: t.textPrimary, height: 1.5),
                        cursorColor: t.accent,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Write.',
                        ),
                      ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ]);
      },
    );
  }
}
