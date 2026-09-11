import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_crm/domain/auth.dart';

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
