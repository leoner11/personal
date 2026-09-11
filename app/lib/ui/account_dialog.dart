import 'package:flutter/material.dart';
import '../domain/auth.dart';
import '../domain/config.dart';
import '../theme/tokens.dart';
import 'widgets/primitives.dart';

/// Sign-in on the Mac. ⚠ A dialog from the sidebar, deliberately NOT a screen
/// and deliberately NOT a wall at launch — local-first is the non-negotiable,
/// and the app is fully usable signed out. This decides one thing: whether the
/// local database also reaches the server.
///
/// Two shells, not one responsive layout, so this is the desktop counterpart
/// to `ui/phone/account_screen.dart` rather than a shared widget. Same reasons
/// as everywhere else: density, controls and the keyboard map all differ.
class AccountDialog extends StatefulWidget {
  const AccountDialog({super.key});

  static Future<void> show(BuildContext c) =>
      showDialog(context: c, builder: (_) => const AccountDialog());

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _secret = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _error;

  AuthState? get _auth => appAuth;

  @override
  void initState() {
    super.initState();
    _auth?.addListener(_onAuth);
    for (final c in [_username, _password, _secret]) {
      c.addListener(() => setState(() {}));
    }
  }

  void _onAuth() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuth);
    _username.dispose();
    _password.dispose();
    _secret.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy &&
      _username.text.trim().isNotEmpty &&
      _password.text.isNotEmpty &&
      (!_registering || _secret.text.trim().isNotEmpty);

  Future<void> _submit() async {
    final auth = _auth;
    if (auth == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await auth.register(
          username: _username.text.trim(),
          password: _password.text,
          registrationSecret: _secret.text.trim(),
          device: 'Mac',
        );
      } else {
        await auth.login(
          username: _username.text.trim(),
          password: _password.text,
          device: 'Mac',
        );
      }
      if (mounted) {
        _password.clear();
        _secret.clear();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final auth = _auth;
    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Account', style: T.screenTitle.copyWith(color: t.textPrimary)),
              const SizedBox(height: 6),
              if (!kSyncEnabled)
                Text(
                    'No server configured. Set kSyncBaseUrl in '
                    'lib/domain/config.dart to your https:// server and '
                    'rebuild. Everything else works without it.',
                    style: T.secondary.copyWith(color: t.textSecondary))
              else if (auth == null)
                Text('Auth is unavailable.',
                    style: T.secondary.copyWith(color: t.textSecondary))
              else if (auth.signedIn) ...[
                Text('Signed in as ${auth.username}',
                    style: T.body.copyWith(color: t.textPrimary)),
                const SizedBox(height: 2),
                Text(kSyncBaseUrl,
                    style: T.secondary.copyWith(color: t.textMuted)),
                const SizedBox(height: 16),
                // ⚠ Says what signing out does NOT do — nobody should fear
                // that signing out to fix sync will take their data with it.
                Text(
                    'Signing out only stops syncing. Everything on this Mac '
                    'stays on this Mac, and your phone stays signed in.',
                    style: T.secondary.copyWith(color: t.textMuted)),
                const SizedBox(height: 16),
                Row(children: [
                  Btn('Sign out', onPressed: auth.logout),
                  const Spacer(),
                  Btn('Close',
                      variant: BtnVariant.primary,
                      onPressed: () => Navigator.pop(context)),
                ]),
              ] else ...[
                Text(
                    'Sign in to sync this Mac with your server. '
                    'The app works fully without it.',
                    style: T.secondary.copyWith(color: t.textSecondary)),
                const SizedBox(height: 14),
                Field(label: 'Username', controller: _username),
                const SizedBox(height: 10),
                _PasswordField(label: 'Password', controller: _password),
                if (_registering) ...[
                  const SizedBox(height: 10),
                  _PasswordField(
                      label: 'Registration secret', controller: _secret),
                  const SizedBox(height: 4),
                  Text(
                      'Only needed once, to claim the server. It is the '
                      'REGISTRATION_SECRET environment variable there.',
                      style: T.secondary.copyWith(color: t.textMuted)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: T.secondary.copyWith(color: t.danger.text)),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  Btn(
                      _registering
                          ? 'I already have an account'
                          : 'First time on this server?',
                      variant: BtnVariant.ghost,
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _registering = !_registering;
                                _error = null;
                              })),
                  const Spacer(),
                  Btn('Cancel',
                      variant: BtnVariant.ghost,
                      onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 8),
                  Btn(
                      _busy
                          ? 'Working…'
                          : (_registering ? 'Create account' : 'Sign in'),
                      variant: BtnVariant.primary,
                      onPressed: _canSubmit ? _submit : null),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ⚠ Obscured, and with autocorrect and suggestions off so the OS keyboard
/// never learns the password.
class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: T.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Container(
          height: D.control,
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(D.radiusControl),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: T.body.copyWith(color: t.textPrimary),
            cursorColor: t.accent,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
