import 'dart:async';

/// Decides WHEN to sync, so nobody has to press a button. What a sync does
/// stays in [SyncEngine]; this only calls [run].
///
/// Three triggers, each covering a gap the others leave:
///   * a local change — [changes] fires; the push follows after [settle] of
///     quiet, so typing a note is one upload, not one per keystroke;
///   * coming back to the app — [resumed], which is when the phone's edits
///     are most likely waiting;
///   * [every] while open — the Mac stays open for days, and without this a
///     phone edit made while you sit in another window never arrives.
///
/// ⚠ NEVER TWO RUNS AT ONCE. A trigger during a run is remembered and runs
/// once more after it — dropping it would lose an edit made mid-upload until
/// the next tick, and running it alongside would push the same rows twice.
class AutoSync {
  AutoSync({
    required this.run,
    required Stream<int> changes,
    this.settle = const Duration(seconds: 5),
    this.every = const Duration(minutes: 3),
  }) {
    // ⚠ Only a count above zero is a local edit. The sync itself writes
    // sync_state too (clearing rows after push and pull); reacting to that
    // would make every sync schedule the next one, forever.
    _changes = changes.listen((dirty) {
      if (dirty > 0) _debounceNow();
    });
    _tick = Timer.periodic(every, (_) => trigger());
  }

  final Future<void> Function() run;
  final Duration settle;
  final Duration every;

  late final StreamSubscription<int> _changes;
  late final Timer _tick;
  Timer? _debounce;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  void _debounceNow() {
    _debounce?.cancel();
    _debounce = Timer(settle, trigger);
  }

  /// The app came back to the foreground.
  void resumed() => trigger();

  /// Sync now, or right after the run already in flight.
  Future<void> trigger() async {
    if (_disposed) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        try {
          await run();
        } catch (_) {
          // Silent, like the engine: the next trigger tries again.
        }
      } while (_again && !_disposed);
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _tick.cancel();
    _changes.cancel();
  }
}
