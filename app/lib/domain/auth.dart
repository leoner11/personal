import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

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
  const TokenStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  static const _kToken = 'sync_token';
  static const _kUser = 'sync_username';

  /// ⚠ Keychain, not SharedPreferences. A bearer token is a password: on
  /// Android, preferences sit in plain XML readable by anyone with a rooted
  /// device or a backup extraction, and this token reaches the entire contact
  /// list and cashflow.
  Future<String?> token() => _storage.read(key: _kToken);
  Future<String?> username() => _storage.read(key: _kUser);

  Future<void> save(String token, String username) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUser, value: username);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUser);
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
      throw AuthException('Could not reach the server. Check the address '
          'and your connection.');
    }

    Map<String, dynamic> decoded = const {};
    try {
      decoded = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      // A proxy error page rather than our JSON.
    }

    if (r.statusCode >= 200 && r.statusCode < 300) return decoded;

    final detail = decoded['detail'] as String?;
    throw AuthException(switch (r.statusCode) {
      401 => 'Wrong username or password.',
      403 => detail ?? 'Registration is closed on this server.',
      409 => 'This server already has an account. Sign in instead.',
      429 => 'Too many attempts. Wait a few minutes and try again.',
      _ => detail ?? 'The server returned an error (${r.statusCode}).',
    });
  }

  /// Claims the deployment. Works once, and only with the deploy-time secret.
  Future<({String token, String username})> register({
    required String username,
    required String password,
    required String registrationSecret,
    required String device,
  }) async {
    final d = await _post(
      '/auth/register',
      {'username': username, 'password': password, 'device': device},
      extraHeaders: {'X-Register-Secret': registrationSecret},
    );
    return (token: d['token'] as String, username: d['username'] as String);
  }

  Future<({String token, String username})> login({
    required String username,
    required String password,
    required String device,
  }) async {
    final d = await _post(
      '/auth/login',
      {'username': username, 'password': password, 'device': device},
    );
    return (token: d['token'] as String, username: d['username'] as String);
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
  String? _username;
  bool _loaded = false;

  String? get token => _token;
  String? get username => _username;
  bool get signedIn => _token != null;

  /// False until the Keychain read finishes. The UI must not render "signed
  /// out" before that or it flashes a sign-in prompt at someone who is not.
  bool get loaded => _loaded;

  Future<void> load() async {
    _token = await _store.token();
    _username = await _store.username();
    _loaded = true;
    notifyListeners();
  }

  Future<void> register({
    required String username,
    required String password,
    required String registrationSecret,
    required String device,
  }) async {
    final r = await _api.register(
      username: username,
      password: password,
      registrationSecret: registrationSecret,
      device: device,
    );
    await _accept(r.token, r.username);
  }

  Future<void> login({
    required String username,
    required String password,
    required String device,
  }) async {
    final r =
        await _api.login(username: username, password: password, device: device);
    await _accept(r.token, r.username);
  }

  Future<void> logout() async {
    final t = _token;
    if (t != null) await _api.logout(t);
    await _store.clear();
    _token = null;
    _username = null;
    notifyListeners();
  }

  /// Called when the server rejects a token mid-sync, so a revoked device
  /// stops claiming to be signed in.
  Future<void> forgetRejectedToken() async {
    await _store.clear();
    _token = null;
    _username = null;
    notifyListeners();
  }

  Future<void> _accept(String token, String username) async {
    await _store.save(token, username);
    _token = token;
    _username = username;
    notifyListeners();
  }
}
