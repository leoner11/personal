import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../data/database.dart';
import 'occasions.dart';

/// The tag vocabulary, held in memory so a slug can be turned into a label
/// synchronously, inside a list row, without nesting a second StreamBuilder in
/// every place a person's chips are drawn.
///
/// ⚠ Same shape as `phoneTodayCount`: one notifier, written from the database,
/// read by whoever is drawing. [bind] keeps it live in production — including
/// through a sync, which is how a tag made on the phone reaches the Mac's
/// chips. Tests skip [bind] (a drift stream subscription outlives a widget
/// test and trips its pending-timer assertion) and call [refresh] instead.
class TagVocab {
  TagVocab._();

  /// ⚠ HOLDS SOFT-DELETED ROWS TOO. Chips read [live], but label lookup must
  /// not: money rows keep the occasion_tag of a tag that was later deleted,
  /// and a ledger line reading 'Deepavali gift — Sri' must not decay into
  /// 'deepavali gift — Sri' because the vocabulary moved on. History keeps the
  /// name it was written with.
  static final ValueNotifier<List<OccasionTagRow>> all =
      ValueNotifier(const []);

  static StreamSubscription<List<OccasionTagRow>>? _sub;

  /// Everything a chip may offer, in the user's own order.
  static List<OccasionTagRow> get live =>
      all.value.where((t) => t.deletedAt == null).toList();

  static OccasionTagRow? bySlug(String slug) {
    for (final t in all.value) {
      if (t.slug == slug) return t;
    }
    return null;
  }

  /// ⚠ FALLS BACK TO THE RAW SLUG, never to a placeholder. A slug with no row
  /// — synced from a newer client, or carried by a money row whose tag predates
  /// this table — still has to render as something the user recognises. The
  /// enum is consulted second so an install that somehow has no seeded rows
  /// still shows real labels rather than 'midAutumn'.
  static String labelFor(String slug) =>
      bySlug(slug)?.label ?? OccasionTag.fromId(slug)?.label ?? slug;

  /// What a brand-new occasion is tagged with before the user picks.
  ///
  /// ⚠ PREFERS newYear, which the enum documents as the 'safe universal
  /// fallback' — the tag you reach for when you do not know enough about
  /// someone to guess. Only when the user has deleted it does this fall back
  /// to whatever is first, because the alternative is defaulting to a tag that
  /// is not in the vocabulary at all: an occasion saved against it would have
  /// no audience, no chip and would fire nothing.
  static String get defaultSlug {
    final tags = live;
    if (tags.isEmpty) return '';
    for (final t in tags) {
      if (t.slug == OccasionTag.newYear.name) return t.slug;
    }
    return tags.first.slug;
  }

  static Future<void> refresh(AppDatabase db) async {
    all.value = await db.select(db.occasionTags).get();
  }

  static void bind(AppDatabase db) {
    _sub?.cancel();
    _sub = db.select(db.occasionTags).watch().listen((rows) => all.value = rows);
  }

  @visibleForTesting
  static Future<void> reset() async {
    await _sub?.cancel();
    _sub = null;
    all.value = const [];
  }
}

/// Creates a tag, or returns the slug of the one that already claims it.
///
/// ⚠ LIVES IN THE DOMAIN because BOTH shells call it. What a tag *is* — how a
/// label becomes a slug, what counts as a collision, what happens to a
/// deleted one — cannot be allowed to differ between the phone and the Mac,
/// or the same typed word makes two different tags depending on where it was
/// typed.
///
/// ⚠ NEVER MINTS A SECOND ROW FOR A LABEL ALREADY IN USE. Two people both
/// reaching for 'Hanukkah' — on two devices, or twice on one — must converge,
/// not end up with two identical chips tagging two different audiences. The
/// slug derives from the label and the id from the slug, so a collision is
/// caught here on one device and by last-write-wins across two.
///
/// ⚠ REVIVES RATHER THAN DUPLICATES. A soft-deleted slug is still taken;
/// adding that label back clears deletedAt on the original, which also keeps
/// the id stable for anything still pointing at it.
Future<String?> createOccasionTag(
  AppDatabase db, {
  required String label,
  String? hint,
  String? greeting,
}) async {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return null;

  final slug = tagSlug(trimmed);
  final existing = await db.allOccasionTagsIncludingDeleted();

  for (final t in existing) {
    if (t.slug != slug && t.label.toLowerCase() != trimmed.toLowerCase()) {
      continue;
    }
    if (t.deletedAt != null) {
      await db.updateOccasionTag(
          t.id,
          OccasionTagsCompanion(
              label: Value(trimmed), deletedAt: const Value(null)));
    }
    await TagVocab.refresh(db);
    return t.slug;
  }

  final order = existing.fold<int>(
      kBuiltInTags.length, (m, t) => t.sortOrder >= m ? t.sortOrder + 1 : m);

  await db.upsertOccasionTag(OccasionTagsCompanion.insert(
    id: seededId('tag:$slug'),
    slug: slug,
    label: trimmed,
    hint: Value((hint ?? '').trim().isEmpty ? null : hint!.trim()),
    greeting: Value((greeting ?? '').trim().isEmpty ? null : greeting!.trim()),
    sortOrder: Value(order),
  ));
  await TagVocab.refresh(db);
  return slug;
}
