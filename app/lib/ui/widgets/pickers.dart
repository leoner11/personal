import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../theme/tokens.dart';
import 'primitives.dart';

/// Searchable person picker. Used wherever something links to a contact —
/// a project's counterparty today, a note or money row later.
class PersonPicker extends StatefulWidget {
  const PersonPicker({super.key, required this.db});
  final AppDatabase db;

  /// Returns the chosen person, or a sentinel with an empty id to mean
  /// "clear the link". Null means the user cancelled.
  static Future<Person?> show(BuildContext c, AppDatabase db) =>
      showDialog<Person>(context: c, builder: (_) => PersonPicker(db: db));

  @override
  State<PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<PersonPicker> {
  final _q = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 420,
        height: 460,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Link a person',
                  style: T.entityName.copyWith(color: t.textPrimary)),
              const SizedBox(height: 10),
              SizedBox(
                height: D.control,
                child: TextField(
                  controller: _q,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: T.body.copyWith(color: t.textPrimary),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: t.subtle,
                    hintText: 'Search',
                    hintStyle: T.body.copyWith(color: t.textMuted),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(D.radiusControl),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<Person>>(
                  stream: widget.db.watchPeople(),
                  builder: (context, snap) {
                    final q = _q.text.trim().toLowerCase();
                    final rows = (snap.data ?? const <Person>[])
                        .where((p) =>
                            q.isEmpty ||
                            p.name.toLowerCase().contains(q) ||
                            (p.company ?? '').toLowerCase().contains(q))
                        .toList();
                    if (rows.isEmpty) {
                      return const EmptyLine('No one matches.');
                    }
                    return ListView(children: [
                      for (final p in rows)
                        GestureDetector(
                          onTap: () => Navigator.pop(context, p),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: SizedBox(
                              height: D.listRowTwoLine,
                              child: Row(children: [
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name,
                                          style: T.body.copyWith(
                                              color: t.textPrimary,
                                              fontWeight: FontWeight.w600)),
                                      Text(p.company ?? '',
                                          style: T.secondary
                                              .copyWith(color: t.textSecondary)),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                    ]);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Btn('Clear link',
                    variant: BtnVariant.ghost,
                    onPressed: () => Navigator.pop(
                        context,
                        Person(
                            id: '',
                            name: '',
                            preferredChannel: 'wa',
                            occasionTags: const [],
                            updatedAt: DateTime.now()))),
                const SizedBox(width: 8),
                Btn('Cancel',
                    variant: BtnVariant.secondary,
                    onPressed: () => Navigator.pop(context)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Project counterpart to [PersonPicker]. Same contract: an empty id means
/// "clear the link", null means cancelled.
class ProjectPicker extends StatefulWidget {
  const ProjectPicker({super.key, required this.db});
  final AppDatabase db;

  static Future<Engagement?> show(BuildContext c, AppDatabase db) =>
      showDialog<Engagement>(context: c, builder: (_) => ProjectPicker(db: db));

  @override
  State<ProjectPicker> createState() => _ProjectPickerState();
}

class _ProjectPickerState extends State<ProjectPicker> {
  final _q = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 420,
        height: 460,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Link a project',
                  style: T.entityName.copyWith(color: t.textPrimary)),
              const SizedBox(height: 10),
              SizedBox(
                height: D.control,
                child: TextField(
                  controller: _q,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: T.body.copyWith(color: t.textPrimary),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: t.subtle,
                    hintText: 'Search',
                    hintStyle: T.body.copyWith(color: t.textMuted),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(D.radiusControl),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<Engagement>>(
                  stream: widget.db.watchEngagements(),
                  builder: (context, snap) {
                    final q = _q.text.trim().toLowerCase();
                    final rows = (snap.data ?? const <Engagement>[])
                        .where((e) =>
                            q.isEmpty || e.name.toLowerCase().contains(q))
                        .toList();
                    if (rows.isEmpty) return const EmptyLine('No projects.');
                    return ListView(children: [
                      for (final e in rows)
                        GestureDetector(
                          onTap: () => Navigator.pop(context, e),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: SizedBox(
                              height: D.listRowTwoLine,
                              child: Row(children: [
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(e.name,
                                          style: T.body.copyWith(
                                              color: t.textPrimary,
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                          [e.type, if ((e.status ?? '').isNotEmpty) e.status!]
                                              .join(' · '),
                                          style: T.secondary.copyWith(
                                              color: t.textSecondary)),
                                    ],
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                    ]);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Btn('Clear link',
                    variant: BtnVariant.ghost,
                    onPressed: () => Navigator.pop(
                        context,
                        Engagement(
                            id: '',
                            name: '',
                            type: 'deal',
                            updatedAt: DateTime.now()))),
                const SizedBox(width: 8),
                Btn('Cancel',
                    variant: BtnVariant.secondary,
                    onPressed: () => Navigator.pop(context)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// The link control used by notes and money rows: shows what is attached and
/// lets it be changed or cleared. ⚠ Both links stay optional — a note with no
/// links is the normal case, not an incomplete one.
class LinkBar extends StatelessWidget {
  const LinkBar({
    super.key,
    required this.db,
    required this.personName,
    required this.projectName,
    required this.onPerson,
    required this.onProject,
  });

  final AppDatabase db;
  final String? personName;
  final String? projectName;
  final ValueChanged<Person?> onPerson;
  final ValueChanged<Engagement?> onProject;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      _chip(
        context,
        label: personName ?? 'Link person',
        set: personName != null,
        onTap: () async {
          final p = await PersonPicker.show(context, db);
          if (p != null) onPerson(p.id.isEmpty ? null : p);
        },
      ),
      _chip(
        context,
        label: projectName ?? 'Link project',
        set: projectName != null,
        onTap: () async {
          final e = await ProjectPicker.show(context, db);
          if (e != null) onProject(e.id.isEmpty ? null : e);
        },
      ),
      if (personName != null || projectName != null)
        Text('tap to change or clear',
            style: T.secondary.copyWith(color: t.textMuted)),
    ]);
  }

  Widget _chip(BuildContext context,
          {required String label,
          required bool set,
          required VoidCallback onTap}) =>
      TagChip(label: label, selected: set, onTap: onTap);
}
