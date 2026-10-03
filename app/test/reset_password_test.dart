import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_crm/domain/auth.dart';
import 'package:personal_crm/domain/config.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/account_dialog.dart';
import 'package:personal_crm/ui/phone/account_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store implements TokenStore {
  String? t, u;
  @override
  Future<String?> token() async => t;
  @override
  Future<String?> username() async => u;
  @override
  Future<void> save(String token, String username) async {
    t = token;
    u = username;
  }

  @override
  Future<void> clear() async => t = u = null;
}

/// A forgotten password, on both shells: email → emailed code → new password.
/// The server's side of it (expiry, five tries, one answer for any address)
/// is in server/core/tests.py.
void main() {
  late _Store store;
  late List<http.Request> calls;

  /// [confirm] is the status the server gives the code; the request for a
  /// code answers [ask].
  Future<AuthState> auth({int ask = 200, int confirm = 200, String? detail}) async {
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    calls = [];
    final a = AuthState(
      store: store,
      api: AuthApi(
        baseUrl: 'https://crm.test',
        client: MockClient((req) async {
          calls.add(req);
          if (req.url.path == '/auth/reset/request') {
            return http.Response(jsonEncode({'detail': 'x'}), ask);
          }
          return http.Response(
              jsonEncode(confirm == 200
                  ? {'token': 'tok-new', 'email': 'leonard@example.com'}
                  : {'detail': detail ?? 'x'}),
              confirm);
        }),
      ),
    );
    await a.load();
    return a;
  }

  Map<String, dynamic> sent(int i) =>
      jsonDecode(calls[i].body) as Map<String, dynamic>;

  group('the calls', () {
    test('asking sends only the email, and signs nobody in', () async {
      final a = await auth();
      await a.requestPasswordReset('leonard@example.com');
      expect(calls.single.url.path, '/auth/reset/request');
      expect(sent(0), {'email': 'leonard@example.com'});
      expect(a.signedIn, isFalse);
    });

    test('the code and a new password sign this device in', () async {
      final a = await auth();
      await a.resetPassword(
          email: 'leonard@example.com',
          code: '123456',
          password: 'a-new-passphrase',
          device: 'iPhone');
      expect(calls.single.url.path, '/auth/reset/confirm');
      expect(sent(0)['code'], '123456');
      expect(a.signedIn, isTrue);
      expect(store.t, 'tok-new');
      expect(a.email, 'leonard@example.com');
    });

    Future<String> failure(Future<void> Function(AuthState) f,
        {int ask = 200, int confirm = 200, String? detail}) async {
      final a = await auth(ask: ask, confirm: confirm, detail: detail);
      try {
        await f(a);
        return 'no exception';
      } on AuthException catch (e) {
        expect(a.signedIn, isFalse);
        return e.message;
      }
    }

    Future<void> confirmWith(AuthState a) => a.resetPassword(
        email: 'a@example.com', code: '000000', password: 'pw', device: 'Mac');

    test('a wrong code says to check it or ask again', () async {
      expect(await failure(confirmWith, confirm: 400),
          contains('not right or has expired'));
    });

    test('a weak password shows the server\'s reason, not a code error',
        () async {
      expect(
          await failure(confirmWith,
              confirm: 422, detail: 'This password is too short.'),
          'This password is too short.');
    });

    test('a server with no mail set up says so', () async {
      expect(await failure((a) => a.requestPasswordReset('a@example.com'), ask: 503),
          contains('not set up on this server'));
    });

    test('a server from before reset existed is not called a wrong password',
        () async {
      // ⚠ The shared 401 wording is "Wrong username or password", which here
      // would be exactly the wrong thing to say.
      final m =
          await failure((a) => a.requestPasswordReset('a@example.com'), ask: 401);
      expect(m, contains('cannot reset passwords'));
      expect(m, isNot(contains('Wrong')));
    });
  });

  test('terms and support live on the sync server, like the policy', () {
    expect(kTermsUrl.toString(), 'https://personal-api.mjcxstudio.com/terms');
    expect(kSupportUrl.toString(), 'https://personal-api.mjcxstudio.com/support');
    expect(termsUrlFor('http://crm.example.com'), isNull);
    expect(supportUrlFor(''), isNull);
  });

  Future<void> beat(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Future<void> surface(WidgetTester tester, Widget home,
      {required bool desktop}) async {
    tester.view.physicalSize =
        desktop ? const Size(1280, 800) : const Size(1170, 2532);
    tester.view.devicePixelRatio = desktop ? 1.0 : 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: home),
    ));
    await tester.pump();
  }

  group('phone', () {
    testWidgets('the whole path: typed email carries over, code, signed in',
        (tester) async {
      final a = await auth();
      await surface(tester, PhoneAccountScreen(auth: a), desktop: false);

      await tester.enterText(find.byType(TextField).first, 'leonard@example.com');
      await tester.pump();
      await tester.tap(find.text('Forgot password?'));
      await beat(tester);

      expect(find.text('Reset password'), findsOneWidget);
      await tester.tap(find.text('Send code'));
      await beat(tester);
      expect(sent(0), {'email': 'leonard@example.com'});
      // ⚠ Never claims the address exists.
      expect(find.textContaining('If leonard@example.com has an account'),
          findsOneWidget);
      expect(find.textContaining('signs out your other devices'), findsOneWidget);

      // Nothing typed yet: the button does nothing.
      await tester.tap(find.text('Set password'));
      await beat(tester);
      expect(calls.length, 1);

      final fields = find.descendant(
          of: find.byType(PhoneResetPasswordSheet),
          matching: find.byType(TextField));
      await tester.enterText(fields.at(0), '123456');
      await tester.enterText(fields.at(1), 'a-new-passphrase');
      await tester.pump();
      await tester.tap(find.text('Set password'));
      await beat(tester);

      expect(sent(1)['email'], 'leonard@example.com');
      expect(sent(1)['device'], isNotEmpty);
      expect(a.signedIn, isTrue);
      expect(find.text('Reset password'), findsNothing);
      expect(find.text('SIGNED IN AS'), findsOneWidget);
    });

    testWidgets('a wrong code keeps the sheet open and says why',
        (tester) async {
      final a = await auth(confirm: 400);
      await surface(tester, PhoneAccountScreen(auth: a), desktop: false);
      await tester.enterText(find.byType(TextField).first, 'leonard@example.com');
      await tester.pump();
      await tester.tap(find.text('Forgot password?'));
      await beat(tester);
      await tester.tap(find.text('Send code'));
      await beat(tester);
      final fields = find.descendant(
          of: find.byType(PhoneResetPasswordSheet),
          matching: find.byType(TextField));
      await tester.enterText(fields.at(0), '000000');
      await tester.enterText(fields.at(1), 'a-new-passphrase');
      await tester.pump();
      await tester.tap(find.text('Set password'));
      await beat(tester);

      expect(find.textContaining('not right or has expired'), findsOneWidget);
      expect(find.text('Reset password'), findsOneWidget);
      expect(a.signedIn, isFalse);
    });

    testWidgets('not offered while creating an account', (tester) async {
      final a = await auth();
      await surface(tester, PhoneAccountScreen(auth: a), desktop: false);
      expect(find.text('Forgot password?'), findsOneWidget);
      await tester.tap(find.text('Create an account'));
      await tester.pump();
      expect(find.text('Forgot password?'), findsNothing);
    });

    testWidgets('terms and support sit with the privacy policy',
        (tester) async {
      final a = await auth();
      await surface(tester, PhoneAccountScreen(auth: a), desktop: false);
      expect(find.text('Terms of service'), findsOneWidget);
      expect(find.text('Help and support'), findsOneWidget);
    });
  });

  group('desktop', () {
    testWidgets('the whole path from the account dialog', (tester) async {
      final a = await auth();
      appAuth = a;
      addTearDown(() => appAuth = null);
      await surface(tester, const Center(child: AccountDialog()), desktop: true);

      // ⚠ Three buttons share this row in a 420pt dialog; an overflow here
      // fails the test, which is the point.
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'leonard@example.com');
      await tester.pump();
      await tester.tap(find.text('Forgot password?'));
      await beat(tester);
      await tester.tap(find.text('Send code'));
      await beat(tester);
      expect(sent(0), {'email': 'leonard@example.com'});

      final fields = find.descendant(
          of: find.byType(ResetPasswordDialog),
          matching: find.byType(TextField));
      await tester.enterText(fields.at(0), '123456');
      await tester.enterText(fields.at(1), 'a-new-passphrase');
      await tester.pump();
      await tester.tap(find.text('Set password'));
      await beat(tester);

      expect(sent(1)['device'], 'Mac');
      expect(a.signedIn, isTrue);
      expect(find.byType(ResetPasswordDialog), findsNothing);
      expect(find.textContaining('Signed in as leonard@example.com'),
          findsOneWidget);
    });
  });
}
