import 'dart:async';

/// Re-runs [load] whenever [changes] fires, for a screen that loads once and
/// would otherwise never hear about writes made elsewhere — another tab, or
/// rows a sync brought down.
///
/// ⚠ A sync writes rows one at a time, so changes arrive in bursts. A change
/// during a load is remembered and loads once more after it: at most two
/// loads per burst, never one per row, and never a stale last word.
class ReloadOnChange {
  ReloadOnChange(Stream<void> changes, this.load) {
    _sub = changes.listen((_) => _poke());
  }

  final Future<void> Function() load;
  late final StreamSubscription<void> _sub;
  bool _loading = false;
  bool _again = false;
  bool _disposed = false;

  Future<void> _poke() async {
    if (_loading) {
      _again = true;
      return;
    }
    _loading = true;
    try {
      do {
        _again = false;
        if (_disposed) return;
        await load();
      } while (_again);
    } finally {
      _loading = false;
    }
  }

  void dispose() {
    _disposed = true;
    _sub.cancel();
  }
}
