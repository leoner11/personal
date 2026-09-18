import 'package:flutter/material.dart';
import '../domain/auth.dart';
import '../domain/channel.dart' show openPrivacyPolicy;
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
  const AccountDialog({super.key, this.privacyPolicyUrl});

  /// Defaults to the server's `/privacy`. Only tests pass one: builds decide
  /// it from kSyncBaseUrl, which a test cannot change.
  final Uri? privacyPolicyUrl;

  static Future<void> show(BuildContext c) =>
      showDialog(context: c, builder: (_) => const AccountDialog());

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _secret = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _error;

  AuthState? get _auth => appAuth;

  Uri? get _policyUrl => widget.privacyPolicyUrl ?? kPrivacyPolicyUrl;

  @override
  void initState() {
    super.initState();
    _auth?.addListener(_onAuth);
    for (final c in [_email, _password, _secret]) {
      c.addListener(() => setState(() {}));
    }
  }

  void _onAuth() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuth);
    _email.dispose();
    _password.dispose();
    _secret.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy &&
      // ⚠ A loose check, not a gate: the server decides what a valid address
      // is, and a legal-but-unusual one must still get through.
      looksLikeEmail(_email.text) &&
      // ⚠ Optional: most servers leave signup open.
      _password.text.isNotEmpty;

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
          email: _email.text.trim(),
          password: _password.text,
          device: 'Mac',
          registrationSecret: _secret.text.trim(),
        );
      } else {
        await auth.login(
          email: _email.text.trim(),
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
    } catch (e) {
      // ⚠ ANYTHING ELSE MUST STILL SHOW. Signing in on the Mac silently did
      // nothing for a day: the server created the account, then saving the
      // token threw because the sandboxed app had no keychain entitlement.
      // That is not an AuthException, so nothing was caught and nothing was
      // said. A failure the user cannot see is the worst kind.
      if (mounted) setState(() => _error = 'This device could not finish: $e');
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
                Text('Signed in as ${auth.email}',
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
                  const SizedBox(width: 8),
                  // ⚠ Ghost, never filled: the house has no filled danger
                  // button, and the dialog behind it asks for the password.
                  Btn('Delete account…',
                      variant: BtnVariant.ghost,
                      onPressed: () => DeleteAccountDialog.show(context, auth)),
                  const Spacer(),
                  Btn('Close',
                      variant: BtnVariant.primary,
                      onPressed: () => Navigator.pop(context)),
                ]),
              ] else ...[
                // ⚠ THE MODE IS STATED, not implied by a button label. The
                // ghost button below only SWITCHES modes, and when the only
                // sign of that was the primary button's label changing from
                // "Sign in" to "Create account", tapping it read as "nothing
                // happened" — and the account was never created.
                Text(_registering ? 'Create an account' : 'Sign in',
                    style: T.entityName.copyWith(color: t.textPrimary)),
                const SizedBox(height: 4),
                Text(
                    _registering
                        ? 'Creates a new account on your server, then signs '
                            'this Mac in. The app works fully without one.'
                        : 'Signs this Mac in to sync with your server. '
                            'The app works fully without it.',
                    style: T.secondary.copyWith(color: t.textSecondary)),
                const SizedBox(height: 14),
                Field(label: 'Email', controller: _email),
                const SizedBox(height: 10),
                _PasswordField(label: 'Password', controller: _password),
                if (_registering) ...[
                  const SizedBox(height: 10),
                  Field(label: 'Invite code (optional)', controller: _secret),
                  const SizedBox(height: 4),
                  Text(
                      'Leave blank unless the server has closed signup with '
                      'REGISTRATION_SECRET.',
                      style: T.secondary.copyWith(color: t.textMuted)),
                  // Said BEFORE the account exists: this is the moment the
                  // data starts leaving the device.
                  if (_policyUrl != null) ...[
                    const SizedBox(height: 8),
                    Text(
                        'With an account, what you sync is stored on the '
                        'server. The privacy policy below explains how it is '
                        'handled.',
                        style: T.secondary.copyWith(color: t.textMuted)),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: T.secondary.copyWith(color: t.danger.text)),
                ],
                const SizedBox(height: 18),
                // ⚠ TWO LINES, not three buttons across. All three on one row
                // overflowed this 420pt dialog and clipped the primary button
                // against the right edge — "I already have an account" is the
                // widest label in the app and grows further in translation.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn(
                      _registering
                          ? 'I already have an account'
                          : 'Create an account',
                      variant: BtnVariant.ghost,
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _registering = !_registering;
                                _error = null;
                              })),
                ),
                const SizedBox(height: 8),
                Row(children: [
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
              // ⚠ In every state, signed in or not (App Store 5.1.1(i)).
              if (_policyUrl != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn('Privacy policy',
                      size: BtnSize.sm,
                      variant: BtnVariant.ghost,
                      onPressed: () => openPrivacyPolicy(_policyUrl)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// In-app account deletion (App Store 5.1.1(v), Google Play). Needs the
/// password again — see core/auth.delete_account for why a token is not
/// enough for the one irreversible thing the server does.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.auth});
  final AuthState auth;

  static Future<void> show(BuildContext context, AuthState auth) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DeleteAccountDialog(auth: auth),
      );

  @override
  State<DeleteAccountDialog> createState() => DeleteAccountDialogState();
}

class DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.deleteAccount(_password.text);
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      // ⚠ ANYTHING ELSE MUST STILL SHOW. Signing in on the Mac silently did
      // nothing for a day: the server created the account, then saving the
      // token threw because the sandboxed app had no keychain entitlement.
      // That is not an AuthException, so nothing was caught and nothing was
      // said. A failure the user cannot see is the worst kind.
      if (mounted) setState(() => _error = 'This device could not finish: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final name = widget.auth.email ?? 'this account';
    return Dialog(
      backgroundColor: t.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(D.radiusPanel)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete the account $name?',
                  style: T.entityName.copyWith(color: t.textPrimary)),
              const SizedBox(height: 8),
              Text(deleteAccountExplainer(name, 'this Mac'),
                  style: T.secondary.copyWith(color: t.textSecondary)),
              const SizedBox(height: 14),
              _PasswordField(label: 'Password', controller: _password),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: T.secondary.copyWith(color: t.danger.text)),
              ],
              const SizedBox(height: 16),
              Row(children: [
                const Spacer(),
                Btn('Cancel',
                    variant: BtnVariant.ghost,
                    onPressed: _busy ? null : () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Btn(_busy ? 'Deleting…' : 'Delete account',
                    onPressed: _busy || _password.text.isEmpty ? null : _delete),
              ]),
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
