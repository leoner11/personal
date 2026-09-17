import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_crm/domain/auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ⚠ Signing in must never become a gate on the app. Local-first is the one
/// non-negotiable in this project — capture happens in meeting rooms with no
/// signal — so these pin the auth layer's behaviour, not a launch flow, and
/// there is deliberately no test asserting that anything is blocked when
/// signed out. Nothing is.
class _FakeStore implements TokenStore {
  String? _token;
  String? _username;
  int clears = 0;

  @override
  Future<String?> token() async => _token;
  @override
  Future<String?> username() async => _username;
  @override
  Future<void> save(String token, String username) async {
    _token = token;
    _username = username;
  }

  @override
  Future<void> clear() async {
    clears++;
    _token = null;
    _username = null;
  }
}

void main() {
  late _FakeStore store;
  setUp(() => store = _FakeStore());

  AuthState stateWith(MockClient client) => AuthState(
        store: store,
        api: AuthApi(client: client, baseUrl: 'https://crm.example.com'),
      );

  MockClient json(int status, Map<String, dynamic> body,
          {void Function(http.Request)? onCall}) =>
      MockClient((req) async {
        onCall?.call(req);
        return http.Response(jsonEncode(body), status,
            headers: {'content-type': 'application/json'});
      });

  group('signing in', () {
    test('a token is kept and the state reports signed in', () async {
      final auth = stateWith(json(200, {'token': 'tok-1', 'username': 'leonard'}));
      await auth.login(username: 'leonard', password: 'pw', device: 'Mac');

      expect(auth.signedIn, isTrue);
      expect(auth.username, 'leonard');
      expect(await store.token(), 'tok-1');
    });

    test('the password is never written to storage', () async {
      // ⚠ Only the token is persisted. A stored password is a password that
      // can be stolen, and the server never needs it again.
      final auth = stateWith(json(200, {'token': 'tok-1', 'username': 'leonard'}));
      await auth.login(
          username: 'leonard', password: 'hunter2-is-a-secret', device: 'Mac');
      expect(await store.token(), isNot(contains('hunter2')));
      expect(await store.username(), 'leonard');
    });

    test('registration sends the secret as a header, not in the body',
        () async {
      // In the body it would land in request logs on the server and any proxy
      // in between.
      String? header;
      String? body;
      final auth = stateWith(json(201, {'token': 't', 'username': 'leonard'},
          onCall: (r) {
        header = r.headers['X-Register-Secret'];
        body = r.body;
      }));
      await auth.register(
          username: 'leonard',
          password: 'pw',
          device: 'Mac',
          registrationSecret: 'invite-code');

      expect(header, 'invite-code');
      expect(body, isNot(contains('invite-code')));
    });

    test('no header is sent when there is no invite code', () async {
      // ⚠ Signup is open on most servers. Sending an empty X-Register-Secret
      // would be compared against the configured one and rejected.
      Map<String, String>? headers;
      final auth = stateWith(
          json(201, {'token': 't', 'username': 'leonard'},
              onCall: (r) => headers = r.headers));
      await auth.register(username: 'leonard', password: 'pw', device: 'Mac');
      expect(headers!.containsKey('X-Register-Secret'), isFalse);
    });
  });

  group('failures say the right thing', () {
    Future<String> messageFor(int status, [Map<String, dynamic>? body]) async {
      final auth = stateWith(json(status, body ?? const {}));
      try {
        await auth.login(username: 'a', password: 'b', device: 'Mac');
        return 'no exception';
      } on AuthException catch (e) {
        return e.message;
      }
    }

    test('401 is a credentials problem', () async {
      expect(await messageFor(401), contains('Wrong username or password'));
    });

    test('429 tells the user to wait, not to change their password', () async {
      expect(await messageFor(429), contains('Too many attempts'));
    });

    test('a signup refused for too many new accounts says to wait an hour',
        () async {
      final auth = stateWith(
          json(429, {'detail': 'too many new accounts from this network'}));
      await expectLater(
          auth.register(username: 'x', password: 'pw', device: 'Mac'),
          throwsA(isA<AuthException>().having(
              (e) => e.message, 'message', contains('Try again in an hour'))));
    });

    test('409 says the username is taken', () async {
      expect(await messageFor(409), contains('username is taken'));
    });

    test('an unreachable server is not reported as bad credentials', () async {
      // ⚠ "Invalid password" when the wifi is down sends someone off to reset
      // a password that was never wrong.
      final auth = stateWith(MockClient((_) async => throw http.ClientException('down')));
      await expectLater(
        auth.login(username: 'a', password: 'b', device: 'Mac'),
        throwsA(isA<AuthException>().having((e) => e.message, 'message',
            contains('Could not reach the server'))),
      );
      expect(auth.signedIn, isFalse);
    });

    test('a failed sign-in leaves nothing stored', () async {
      final auth = stateWith(json(401, {}));
      try {
        await auth.login(username: 'a', password: 'b', device: 'Mac');
      } on AuthException {
        // expected
      }
      expect(await store.token(), isNull);
    });
  });

  group('signing out', () {
    test('clears the token even when the server cannot be reached', () async {
      // ⚠ Someone signing out because a phone was lost must not be told "no"
      // by a network error.
      final auth = AuthState(
        store: store,
        api: AuthApi(
          client: MockClient((_) async => throw http.ClientException('down')),
          baseUrl: 'https://crm.example.com',
        ),
      );
      await store.save('tok-1', 'leonard');
      await auth.load();
      expect(auth.signedIn, isTrue);

      await auth.logout();
      expect(auth.signedIn, isFalse);
      expect(await store.token(), isNull);
    });

    test('a rejected token is forgotten rather than retried forever', () async {
      // What the sync engine calls on a 401. Sitting on a token the server has
      // revoked is the armed-and-dead state this project keeps designing away.
      final auth = stateWith(json(200, {}));
      await store.save('tok-1', 'leonard');
      await auth.load();

      await auth.forgetRejectedToken();
      expect(auth.signedIn, isFalse);
      expect(store.clears, 1);
    });
  });


  group('deleting the account', () {
    // Signs in first, then swaps in the server behaviour under test.
    Future<AuthState> signedIn(
        Future<http.Response> Function(http.Request) onDelete) async {
      SharedPreferences.setMockInitialValues({
        'sync_owner': 'leonard',
        'last_synced_at': '2026-09-17T00:00:00Z',
      });
      final auth = AuthState(
        store: store,
        api: AuthApi(
          baseUrl: 'https://crm.example.com',
          client: MockClient((req) => req.url.path == '/auth/login'
              ? Future.value(http.Response(
                  jsonEncode({'token': 'tok-1', 'username': 'leonard'}), 200))
              : onDelete(req)),
        ),
      );
      await auth.login(username: 'leonard', password: 'pw', device: 'Mac');
      return auth;
    }

    Future<http.Response> Function(http.Request) reply(int status,
            {void Function(http.Request)? onCall}) =>
        (req) async {
          onCall?.call(req);
          return http.Response(jsonEncode({'detail': 'x'}), status);
        };

    test('sends the password in the body with the token, then signs out',
        () async {
      late http.Request seen;
      final auth = await signedIn(
          reply(200, onCall: (r) => seen = r));

      await auth.deleteAccount('a-long-passphrase-1');

      expect(seen.url.path, '/auth/delete');
      expect(seen.url.query, isEmpty, reason: 'never in a URL — URLs get logged');
      expect(seen.headers['Authorization'], 'Bearer tok-1');
      expect(jsonDecode(seen.body), {'password': 'a-long-passphrase-1'});
      expect(auth.signedIn, isFalse);
      expect(await store.token(), isNull);
    });

    test("forgets whose data this device held, so the next sign-up is a first one",
        () async {
      // Otherwise re-registering would ask "combine or replace?" about an
      // account that no longer exists.
      final auth = await signedIn(reply(200));
      await auth.deleteAccount('pw');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sync_owner'), isNull);
      expect(prefs.getString('last_synced_at'), isNull);
    });

    test('a wrong password says so, deletes nothing, and stays signed in',
        () async {
      final auth = await signedIn(reply(403));

      await expectLater(
          auth.deleteAccount('typo'),
          throwsA(isA<AuthException>().having((e) => e.message, 'message',
              'That password is not right. Nothing was deleted.')));
      expect(auth.signedIn, isTrue, reason: 'a typo must not sign anyone out');
      // ⚠ The KEYCHAIN too, not just memory — or the next launch would be
      // signed out after a delete that never happened.
      expect(await store.token(), 'tok-1');
      expect((await SharedPreferences.getInstance()).getString('sync_owner'),
          'leonard');
    });

    test('a lost connection does not claim nothing was deleted', () async {
      // ⚠ The request may have landed and the response gone missing.
      final auth = await signedIn(
          (_) async => throw http.ClientException('offline'));

      await expectLater(
          auth.deleteAccount('pw'),
          throwsA(isA<AuthException>().having((e) => e.message, 'message',
              allOf(contains('may or may not'), isNot(contains('Nothing was deleted'))))));
      expect(auth.signedIn, isTrue);
    });

    test('a dead token does not claim nothing was deleted either', () async {
      // A retry after a lost response lands here — because the account IS gone.
      final auth = await signedIn(reply(401));
      await expectLater(
          auth.deleteAccount('pw'),
          throwsA(isA<AuthException>().having((e) => e.message, 'message',
              allOf(contains('may already be gone'),
                  isNot(contains('Wrong username'))))));
    });
  });

  group('startup', () {
    test('loaded is false until the keychain read finishes', () async {
      // ⚠ Rendering "signed out" before the read completes flashes a sign-in
      // prompt at someone who is signed in.
      final auth = stateWith(json(200, {}));
      expect(auth.loaded, isFalse);
      await auth.load();
      expect(auth.loaded, isTrue);
    });

    test('a stored token is restored across launches', () async {
      await store.save('tok-1', 'leonard');
      final auth = stateWith(json(200, {}));
      await auth.load();
      expect(auth.signedIn, isTrue);
      expect(auth.username, 'leonard');
    });
  });
}
