import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_crm/domain/auth.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/account_dialog.dart';
import 'package:personal_crm/ui/phone/account_screen.dart';
import 'package:personal_crm/ui/phone/phone_primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store implements TokenStore {
  String? t = 'tok-1', u = 'leonard@example.com';
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

/// The delete-account surfaces on both shells. Behaviour of the call itself
/// is in auth_test.dart; these pin what the person sees before they commit.
void main() {
  late _Store store;
  late int deleteCalls;

  Future<AuthState> auth(int status) async {
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    deleteCalls = 0;
    final a = AuthState(
      store: store,
      api: AuthApi(
        baseUrl: 'https://crm.test',
        client: MockClient((req) async {
          deleteCalls++;
          return http.Response(jsonEncode({'detail': 'x'}), status);
        }),
      ),
    );
    await a.load();
    return a;
  }

  Future<void> beat(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Future<void> host(WidgetTester tester, Widget Function(BuildContext) open,
      {bool desktop = false}) async {
    // ⚠ Shell-shaped: a 400pt desktop dialog on a 390pt phone surface
    // overflows for reasons that say nothing about the Mac.
    tester.view.physicalSize =
        desktop ? const Size(1280, 800) : const Size(1170, 2532);
    tester.view.devicePixelRatio = desktop ? 1.0 : 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: Builder(builder: open)),
    ));
    await tester.tap(find.text('open'));
    await beat(tester);
  }

  group('phone', () {
    Widget opener(AuthState a) => Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => PhoneSheet.show<void>(
                  context, (_) => PhoneDeleteAccountSheet(auth: a)),
              child: const Text('open'),
            ),
          ),
        );

    testWidgets('says what goes and what stays, and needs the password',
        (tester) async {
      final a = await auth(200);
      await host(tester, (_) => opener(a));

      expect(find.text('Delete leonard@example.com?'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(find.textContaining('The data on this phone stays on this phone'),
          findsOneWidget);

      // Nothing typed: the button does nothing.
      await tester.tap(find.text('Delete'));
      await beat(tester);
      expect(deleteCalls, 0);
    });

    testWidgets('a wrong password shows the reason and keeps the sheet open',
        (tester) async {
      final a = await auth(403);
      await host(tester, (_) => opener(a));

      await tester.enterText(find.byType(TextField), 'typo');
      await tester.pump();
      await tester.tap(find.text('Delete'));
      await beat(tester);

      expect(deleteCalls, 1);
      expect(find.text('That password is not right. Nothing was deleted.'),
          findsOneWidget);
      expect(find.text('Delete leonard@example.com?'), findsOneWidget);
      expect(a.signedIn, isTrue);
    });

    testWidgets('the right password deletes, signs out and closes', (tester) async {
      final a = await auth(200);
      await host(tester, (_) => opener(a));

      await tester.enterText(find.byType(TextField), 'a-long-passphrase-1');
      await tester.pump();
      await tester.tap(find.text('Delete'));
      await beat(tester);

      expect(a.signedIn, isFalse);
      expect(find.text('Delete leonard@example.com?'), findsNothing);
    });
  });

  group('desktop', () {
    testWidgets('says what stays on the Mac and needs the password',
        (tester) async {
      final a = await auth(200);
      await host(
          tester,
          (context) => Center(
                child: TextButton(
                  onPressed: () => DeleteAccountDialog.show(context, a),
                  child: const Text('open'),
                ),
              ),
          desktop: true);

      expect(find.text('Delete the account leonard@example.com?'), findsOneWidget);
      expect(find.textContaining('The data on this Mac stays on this Mac'),
          findsOneWidget);
      await tester.tap(find.text('Delete account'));
      await beat(tester);
      expect(deleteCalls, 0);

      // Not dismissible by a stray click outside.
      await tester.tapAt(const Offset(5, 5));
      await beat(tester);
      expect(find.text('Delete the account leonard@example.com?'), findsOneWidget);
    });
  });
}
