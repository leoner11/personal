import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'sync.dart';

/// Sign-in for sync.
///
/// ⚠ SIGNING IN IS NOT A GATE ON THE APP. It never blocks a screen, and there
/// is no login wall at launch. Local-first is the one non-negotiable in this
/// project — capture happens in meeting rooms with no signal — so the app is
/// fully usable signed out, and signing in only decides whether the local
/// database also reaches the server. A login screen in front of a local-first
/// app is the single easiest way to destroy the thing it is for.
///
/// ⚠ NATIVE, NOT WEB. There is no session cookie and no CSRF: a phone has no
/// ambient credential a hostile page could make it send. The server returns an
/// opaque token, it lives in the Keychain / Android Keystore, and it rides in
/// `Authorization: Bearer …`. That is the same header /sync always took.
class TokenStore {
  const TokenStore([this._storage = const FlutterSecureStorage(), this._macDir]);
  final FlutterSecureStorage _storage;

  /// Only tests pass this; production asks path_provider. See [_sessionFile].
  final Directory? _macDir;

  static const _kToken = 'sync_token';
  static const _kUser = 'sync_username';

  /// ⚠ macOS CANNOT USE THE KEYCHAIN HERE, and this is not a preference.
  /// The Mac app is sandboxed and ad-hoc signed (no certificate), which is
  /// what lets its zip be handed to anyone; a sandboxed app with no signing
  /// team has no keychain access group, so every write fails with
  /// errSecMissingEntitlement. That failure is how signing in appeared to do
  /// nothing at all: the server made the account, saving the token threw.
  /// Adding the entitlement would force real signing and break those zips.
  ///
  /// So macOS keeps the token in a 0600 file inside the app's sandbox
  /// container. Weaker than the keychain — another program running as this
  /// user could read it — and accepted knowingly for one revocable device
  /// token. ⚠ REPLACE THIS with keychain storage the moment the app is signed
  /// with a paid Developer ID, which is also when the zips can be notarized.
  bool get _useFile => Platform.isMacOS;

  /// ⚠ Keychain/Keystore everywhere else. A bearer token is a password: on
  /// Android, preferences sit in plain XML readable by anyone with a rooted
  /// device or a backup extraction, and this token reaches the entire contact
  /// list and cashflow.
  Future<String?> token() async {
    if (!_useFile) return _storage.read(key: _kToken);
    final session = await _read();
    return session == null ? null : session['token'] as String?;
  }

  Future<String?> username() async {
    if (!_useFile) return _storage.read(key: _kUser);
    final session = await _read();
    return session == null ? null : session['username'] as String?;
  }

  Future<void> save(String token, String username) async {
    if (_useFile) return _write({'token': token, 'username': username});
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUser, value: username);
  }

  Future<void> clear() async {
    if (_useFile) {
      final f = await _sessionFile();
      if (f.existsSync()) await f.delete();
      return;
    }
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUser);
  }

  Future<File> _sessionFile() async {
    final dir = _macDir ?? await getApplicationSupportDirectory();
    return File('${dir.path}/session.json');
  }

  Future<Map<String, dynamic>?> _read() async {
    final f = await _sessionFile();
    if (!f.existsSync()) return null;
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      // A truncated or hand-edited file means "signed out", never a crash.
      return null;
    }
  }

  Future<void> _write(Map<String, dynamic> session) async {
    final f = await _sessionFile();
    await f.writeAsString(jsonEncode(session), flush: true);
    // ⚠ Best effort, and after the write: Dart cannot create a file with a
    // mode. The container is already private to this user; this narrows it to
    // the user alone rather than the user's group as well.
    try {
      await Process.run('chmod', ['600', f.path]);
    } catch (_) {}
  }
}

/// What went wrong, in words meant for the person reading them.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? kSyncBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _u(String path) => Uri.parse('$_baseUrl$path');

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? extraHeaders,
    Map<int, String> messages = const {},
    String? unreachable,
  }) async {
    late http.Response r;
    try {
      r = await _client
          .post(
            _u(path),
            headers: {
              'Content-Type': 'application/json',
              ...?extraHeaders,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      // ⚠ A network failure is not a credentials failure, and saying
      // "invalid password" when the wifi is down sends someone to reset a
      // password that was always fine.
      throw AuthException(unreachable ??
          'Could not reach the server. Check the address and your connection.');
    }

    Map<String, dynamic> decoded = const {};
    try {
      decoded = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      // A proxy error page rather than our JSON.
    }

    if (r.statusCode >= 200 && r.statusCode < 300) return decoded;

    final detail = decoded['detail'] as String?;
    final specific = messages[r.statusCode];
    if (specific != null) throw AuthException(specific);
    throw AuthException(switch (r.statusCode) {
      401 => 'Wrong username or password.',
      403 => detail ?? 'Registration is closed on this server.',
      409 => 'That email already has an account. Sign in instead.',
      // ⚠ Two different 429s. Signup is capped per network per hour; telling
      // someone to "wait a few minutes" there sends them back too early.
      429 => detail == 'too many new accounts from this network'
          ? 'Too many new accounts from this network. Try again in an hour.'
          : 'Too many attempts. Wait a few minutes and try again.',
      _ => detail ?? 'The server returned an error (${r.statusCode}).',
    });
  }

  /// Creates an account. [registrationSecret] is only needed on a server that
  /// has closed signup with REGISTRATION_SECRET; most will leave it open.
  Future<({String token, String email})> register({
    required String email,
    required String password,
    required String device,
    String registrationSecret = '',
  }) async {
    final d = await _post(
      '/auth/register',
      {'email': email, 'password': password, 'device': device},
      // ⚠ A header, never the body: request bodies land in server and proxy
      // logs, and this is an invite code.
      extraHeaders: registrationSecret.isEmpty
          ? null
          : {'X-Register-Secret': registrationSecret},
    );
    return (token: d['token'] as String, email: _emailOf(d));
  }

  Future<({String token, String email})> login({
    required String email,
    required String password,
    required String device,
  }) async {
    final d = await _post(
      '/auth/login',
      {'email': email, 'password': password, 'device': device},
    );
    return (token: d['token'] as String, email: _emailOf(d));
  }

  /// ⚠ Falls back to the old key. A server deployed before the switch to
  /// email answers with "username"; reading only "email" would crash a
  /// sign-in that actually succeeded.
  static String _emailOf(Map<String, dynamic> d) =>
      (d['email'] ?? d['username'] ?? '') as String;

  /// Deletes the account on the server, with everything it ever synced.
  ///
  /// ⚠ NOT best-effort, unlike [logout]. A quiet failure would leave someone
  /// believing their data is gone from a server that still holds all of it,
  /// so every failure throws — and each message claims only what is known.
  /// A wrong password is definitely "nothing deleted"; a lost connection or a
  /// dead token is not, because the server may have acted before the response
  /// went missing.
  Future<void> deleteAccount({
    required String token,
    required String password,
  }) async {
    await _post(
      '/auth/delete',
      {'password': password},
      extraHeaders: {'Authorization': 'Bearer $token'},
      messages: const {
        // ⚠ 403 from here means the PASSWORD; 401 means the TOKEN. The shared
        // wording ("Wrong username or password") fits neither.
        403: 'That password is not right. Nothing was deleted.',
        // ⚠ NOT "nothing was deleted". A delete whose response was lost on
        // the way back leaves this token dead because the account IS gone —
        // and the retry lands here. Sign-in tells them which it was.
        401: 'This device is no longer signed in. If you just tried to '
            'delete the account, it may already be gone — signing in again '
            'will tell you.',
      },
      // Same reason: a timeout can fall after the server acted.
      unreachable: 'Could not reach the server, so the account may or may not '
          'have been deleted. Check your connection and try again.',
    );
  }

  /// ⚠ Best effort. If the server cannot be reached we still forget the token
  /// locally — a user tapping Sign out on a lost-phone panic must not be told
  /// "no". The server-side row is then revoked from the other device instead.
  Future<void> logout(String token) async {
    try {
      await _client.post(
        _u('/auth/logout'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}

/// The signed-in state, for the UI to listen to.
///
/// ⚠ Module-level, set once in `main()`, same pattern as `appNotifier`. The
/// alternative is threading it through both shells for one consumer each.
AuthState? appAuth;

class AuthState extends ChangeNotifier {
  AuthState({TokenStore? store, AuthApi? api})
      : _store = store ?? const TokenStore(),
        _api = api ?? AuthApi();

  final TokenStore _store;
  final AuthApi _api;

  String? _token;
  String? _email;
  bool _loaded = false;

  String? get token => _token;

  /// The account's email address — the identifier, chosen over a username
  /// because it is unique by nature and is what a password reset would need.
  String? get email => _email;
  bool get signedIn => _token != null;

  /// False until the Keychain read finishes. The UI must not render "signed
  /// out" before that or it flashes a sign-in prompt at someone who is not.
  bool get loaded => _loaded;

  Future<void> load() async {
    _token = await _store.token();
    _email = await _store.username();
    _loaded = true;
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String device,
    String registrationSecret = '',
  }) async {
    final r = await _api.register(
      email: email,
      password: password,
      device: device,
      registrationSecret: registrationSecret,
    );
    await _accept(r.token, r.email);
  }

  Future<void> login({
    required String email,
    required String password,
    required String device,
  }) async {
    final r =
        await _api.login(email: email, password: password, device: device);
    await _accept(r.token, r.email);
  }

  Future<void> logout() async {
    final t = _token;
    if (t != null) await _api.logout(t);
    await _store.clear();
    _token = null;
    _email = null;
    notifyListeners();
  }

  /// Deletes the account, then signs this device out.
  ///
  /// ⚠ This device's DATA STAYS. It was local before the account existed and
  /// is local after; what goes is the server's copy. The device also forgets
  /// which account its data belonged to, so a later sign-up — any username,
  /// including this one again — is a first sign-up and uploads it without a
  /// combine-or-replace question about an account that no longer exists.
  Future<void> deleteAccount(String password) async {
    final t = _token;
    if (t == null) {
      throw AuthException('Not signed in. Nothing was deleted.');
    }
    await _api.deleteAccount(token: t, password: password);
    await SyncEngine.forgetDeviceOwnership();
    await _store.clear();
    _token = null;
    _email = null;
    notifyListeners();
  }

  /// Called when the server rejects a token mid-sync, so a revoked device
  /// stops claiming to be signed in.
  Future<void> forgetRejectedToken() async {
    await _store.clear();
    _token = null;
    _email = null;
    notifyListeners();
  }

  Future<void> _accept(String token, String email) async {
    await _store.save(token, email);
    _token = token;
    _email = email;
    notifyListeners();
  }
}

/// What deleting an account does, worded once for both shells. [device] is
/// "this Mac" / "this phone".
///
/// ⚠ Says what goes AND what stays. Someone deleting an account to leave the
/// service needs to know the server copy is gone; someone doing it to "reset
/// sync" needs to know it does not wipe the device in their hand.
String deleteAccountExplainer(String username, String device) =>
    'This deletes $username and everything synced to it from the server — '
    'people, notes, money, all of it — and signs out your other devices. '
    'It cannot be undone.\n\nThe data on $device stays on $device.';

/// Enough of a check to keep an obvious typo from becoming a failed request.
/// ⚠ Deliberately loose: the server validates properly, and an address that
/// is legal but strange must not be refused by a regex written in an app.
bool looksLikeEmail(String value) {
  final v = value.trim();
  final at = v.indexOf('@');
  return at > 0 && v.indexOf('.', at) > at + 1 && !v.contains(' ') && v.length > 4;
}
