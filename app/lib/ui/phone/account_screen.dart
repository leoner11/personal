import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../domain/auth.dart';
import '../../domain/config.dart';
import '../../domain/money_fmt.dart' show fmtAgo;
import '../../domain/sync.dart';
import '../../theme/tokens.dart';
import '../widgets/app_icon.dart';
import 'phone_primitives.dart';

/// Sign-in, for sync only.
///
/// ⚠ THIS IS NOT A LOGIN WALL. The app is fully usable signed out — capture,
/// Today, People, all of it. Local-first is the one non-negotiable in this
/// project, and putting a login in front of an app whose whole premise is
/// "works in a meeting room with no signal" would destroy the thing it is
/// for. Signing in decides one thing: whether the local database also reaches
/// the server.
///
/// v2 keeps the structure deliberately (§4: the quiet screen gets perfect
/// typography, not new furniture) and adds exactly two things: the password
/// reveal eye, and the quiet sync line on the signed-in card.
class PhoneAccountScreen extends StatefulWidget {
  const PhoneAccountScreen({super.key, required this.auth, this.db});
  final AuthState auth;

  /// Handle for the sync line's last-synced stamp (domain/sync.dart). The
  /// Review hub owns the wiring; null simply means no sync diagnostics.
  final AppDatabase? db;

  @override
  State<PhoneAccountScreen> createState() => _PhoneAccountScreenState();
}

class _PhoneAccountScreenState extends State<PhoneAccountScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _secret = TextEditingController();
  bool _registering = false;
  bool _busy = false;

  /// The reveal state. ⚠ Resets to obscured by construction: this State dies
  /// with the screen, so a reopened Account always starts blind again.
  bool _reveal = false;

  String? _error;

  /// Last sync, read once per sign-in. Null + loaded means the engine has
  /// never finished a round-trip on this device.
  DateTime? _lastSynced;
  bool _syncLoaded = false;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuth);
    for (final c in [_username, _password, _secret]) {
      c.addListener(() => setState(() {}));
    }
    _loadSync();
  }

  void _onAuth() {
    setState(() {});
    if (widget.auth.signedIn) {
      _loadSync();
    }
  }

  /// Reads the shared `last_synced_at` stamp the engine writes after every
  /// successful round-trip. ⚠ The phone runs no sync engine yet, so until a
  /// sync is wired on this device this reads null and the card says
  /// `Never synced` — the honest state, not a fake timestamp.
  Future<void> _loadSync() async {
    final db = widget.db;
    if (db == null || !widget.auth.signedIn) {
      return;
    }
    final at = await SyncEngine(db,
            baseUrl: kSyncBaseUrl,
            token: widget.auth.token ?? '',
            account: widget.auth.username ?? '')
        .lastSynced();
    if (mounted) {
      setState(() {
        _lastSynced = at;
        _syncLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuth);
    _username.dispose();
    _password.dispose();
    _secret.dispose();
    super.dispose();
  }

  String get _device => Platform.isAndroid ? 'Android phone' : 'iPhone';

  bool get _canSubmit =>
      !_busy &&
      _username.text.trim().isNotEmpty &&
      // ⚠ The secret is NOT required — most servers leave signup open. Making
      // it mandatory here would block registration against every one of them.
      _password.text.isNotEmpty;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await widget.auth.register(
          username: _username.text.trim(),
          password: _password.text,
          device: _device,
          registrationSecret: _secret.text.trim(),
        );
      } else {
        await widget.auth.login(
          username: _username.text.trim(),
          password: _password.text,
          device: _device,
        );
      }
      if (!mounted) return;
      _password.clear();
      _secret.clear();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneScaffold(
      title: 'Account',
      child: AbsorbPointer(
        // ⚠ While busy, everything waits: PhoneField has no enabled flag, so
        // the absorbing wrapper is how "all other controls disabled" is kept
        // honest without inventing primitive API.
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              PD.screenPad, 0, PD.screenPad, PD.sectionGap),
          children: [
            if (!kSyncEnabled)
              PhoneCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No server configured',
                        style: PT.body.copyWith(
                            color: t.textPrimary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    // ⚠ Says what to do, not just what is wrong. And names
                    // https specifically, because an http:// URL is treated as
                    // no server at all rather than leaking the token over it.
                    Text(
                        'Set kSyncBaseUrl in lib/domain/config.dart to your '
                        'https:// server and rebuild. Everything here works '
                        'without it — sync is the only thing that does not.',
                        style: PT.secondary.copyWith(color: t.textSecondary)),
                  ],
                ),
              )
            else if (widget.auth.signedIn)
              _SignedIn(
                  auth: widget.auth,
                  db: widget.db,
                  lastSynced: _lastSynced,
                  syncLoaded: _syncLoaded)
            else ...[
              Text(
                  'Sign in to sync this phone with your server. '
                  'The app works fully without it.',
                  style: PT.secondary.copyWith(color: t.textSecondary)),
              const SizedBox(height: PD.sectionGap),
              PhoneField(
                  label: 'Username',
                  controller: _username,
                  textCapitalization: TextCapitalization.none),
              const SizedBox(height: PD.groupGap),
              _PasswordField(controller: _password, reveal: _reveal,
                  onToggle: () => setState(() => _reveal = !_reveal)),
              if (_registering) ...[
                const SizedBox(height: PD.groupGap),
                PhoneField(
                    label: 'Invite code (optional)',
                    controller: _secret,
                    hint: 'only if your server requires one',
                    textCapitalization: TextCapitalization.none),
                const SizedBox(height: 6),
                Text(
                    'Leave blank unless the server has closed signup with '
                    'REGISTRATION_SECRET.',
                    style: PT.secondary.copyWith(color: t.textMuted)),
              ],
              if (_error != null) ...[
                const SizedBox(height: PD.groupGap),
                Text(_error!,
                    style: PT.secondary.copyWith(color: t.danger.text)),
              ],
              const SizedBox(height: PD.sectionGap),
              PhoneBtn(
                  _busy
                      ? 'Working…'
                      : (_registering ? 'Create account' : 'Sign in'),
                  variant: PhoneBtnVariant.primary,
                  expand: true,
                  onPressed: _canSubmit ? _submit : null),
              const SizedBox(height: PD.groupGap),
              PhoneBtn(
                  _registering
                      ? 'I already have an account'
                      : 'Create an account',
                  variant: PhoneBtnVariant.ghost,
                  expand: true,
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _registering = !_registering;
                            _error = null;
                          })),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({
    required this.auth,
    required this.lastSynced,
    required this.syncLoaded,
    this.db,
  });
  final AuthState auth;
  final AppDatabase? db;
  final DateTime? lastSynced;
  final bool syncLoaded;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // Desktop `_Footer` grammar: quiet micro text, never a button, never a
    // spinner, never a dialog. attention.text only when it matters — stale
    // past an hour means sync has silently stopped working.
    final stale = lastSynced != null &&
        DateTime.now().difference(lastSynced!) > const Duration(hours: 1);
    final syncColor = stale ? t.attention.text : t.textMuted;
    final syncLine = !syncLoaded
        ? null
        : lastSynced == null
            ? 'Never synced'
            : 'Synced ${fmtAgo(lastSynced)}';
    // ⚠ The engine's 401 `Sign in again` state lives on the SyncEngine
    // INSTANCE (domain/sync.dart), and the phone owns no engine — there is
    // no reachable backing field for it here, so there is no line pretending
    // otherwise.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhoneCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SIGNED IN AS',
                  style: PT.micro
                      .copyWith(color: t.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text(auth.username ?? '—',
                  style: PT.entityName.copyWith(color: t.textPrimary)),
              const SizedBox(height: 6),
              Text(kSyncBaseUrl,
                  style: PT.secondary.copyWith(color: t.textSecondary)),
              if (syncLine != null) ...[
                const SizedBox(height: 6),
                Text(syncLine, style: PT.micro.copyWith(color: syncColor)),
              ],
            ],
          ),
        ),
        const SizedBox(height: PD.sectionGap),
        // Direct, no confirm: server-side revocation is best-effort by
        // design, and the reassurance line beneath IS the safety story.
        PhoneBtn('Sign out',
            variant: PhoneBtnVariant.secondary,
            expand: true,
            onPressed: auth.logout),
        const SizedBox(height: 8),
        // ⚠ Says what signing out does NOT do. Someone signing out to fix a
        // sync problem needs to know their data is not about to vanish.
        Text(
            'Signing out only stops syncing. Everything on this phone stays '
            'on this phone, and the other device stays signed in.',
            style: PT.secondary.copyWith(color: t.textMuted)),
      ],
    );
  }
}

/// Obscured by default; the 44pt eye reveals it. ⚠ While revealed, the visible
/// text IS the state — the icon never swaps to a second glyph. Excluded from
/// autocorrect and suggestions either way: an iOS keyboard must never learn
/// the password.
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.reveal,
    required this.onToggle,
  });
  final TextEditingController controller;
  final bool reveal;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PhoneField(
      label: 'Password',
      controller: controller,
      obscure: !reveal,
      autocorrect: false,
      enableSuggestions: false,
      suffix: GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: PD.tapMin,
          height: PD.tapMin,
          child: Center(
            child: AppIcon(Ic.eye, size: 20, color: t.textSecondary),
          ),
        ),
      ),
    );
  }
}
