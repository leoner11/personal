import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../../domain/auth.dart';
import '../../domain/config.dart';
import '../../theme/tokens.dart';
import 'phone_primitives.dart';

/// Sign-in, for sync only.
///
/// ⚠ THIS IS NOT A LOGIN WALL. The app is fully usable signed out — capture,
/// Today, the run screen, money, notes, all of it. Local-first is the one
/// non-negotiable in this project, and putting a login in front of an app
/// whose whole premise is "works in a meeting room with no signal" would
/// destroy the thing it is for. Signing in decides one thing: whether the
/// local database also reaches the server.
class PhoneAccountScreen extends StatefulWidget {
  const PhoneAccountScreen({super.key, required this.auth});
  final AuthState auth;

  @override
  State<PhoneAccountScreen> createState() => _PhoneAccountScreenState();
}

class _PhoneAccountScreenState extends State<PhoneAccountScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _secret = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuth);
    for (final c in [_username, _password, _secret]) {
      c.addListener(() => setState(() {}));
    }
  }

  void _onAuth() => setState(() {});

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
    return PhoneBody(
      title: 'Account',
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
                  // ⚠ Says what to do, not just what is wrong. And names https
                  // specifically, because an http:// URL is treated as no
                  // server at all rather than leaking the token over it.
                  Text(
                      'Set kSyncBaseUrl in lib/domain/config.dart to your '
                      'https:// server and rebuild. Everything here works '
                      'without it — sync is the only thing that does not.',
                      style: PT.secondary.copyWith(color: t.textSecondary)),
                ],
              ),
            )
          else if (widget.auth.signedIn)
            _SignedIn(auth: widget.auth)
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
            _Password(controller: _password),
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
              Text(_error!, style: PT.secondary.copyWith(color: t.danger.text)),
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
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.auth});
  final AuthState auth;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
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
            ],
          ),
        ),
        const SizedBox(height: PD.sectionGap),
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

/// ⚠ Obscured, and excluded from autocorrect and suggestions — an iOS
/// keyboard will otherwise happily learn the password and offer it later.
class _Password extends StatelessWidget {
  const _Password({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PASSWORD',
            style: PT.micro.copyWith(color: t.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: PD.control),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(D.radiusControl),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: PT.body.copyWith(color: t.textPrimary),
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
