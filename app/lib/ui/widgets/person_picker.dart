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
