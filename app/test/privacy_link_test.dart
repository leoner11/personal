import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/domain/auth.dart';
import 'package:personal_crm/domain/config.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/account_dialog.dart';
import 'package:personal_crm/ui/phone/account_screen.dart';

class _Store implements TokenStore {
  @override
  Future<String?> token() async => null;
  @override
  Future<String?> username() async => null;
  @override
  Future<void> save(String token, String username) async {}
  @override
  Future<void> clear() async {}
}

/// The in-app privacy policy link (App Store 5.1.1(i)).
void main() {
  group('where the link points', () {
    test('the policy lives on the server the app syncs with', () {
      expect(privacyPolicyUrlFor('https://crm.example.com').toString(),
          'https://crm.example.com/privacy');
      expect(privacyPolicyUrlFor('https://crm.example.com/').toString(),
          'https://crm.example.com/privacy');
    });

    test('no https server, no link — the same rule as sync itself', () {
      // ⚠ An http:// URL disables sync rather than leaking the token; the
      // policy link follows it, so it can never point at a server the app
      // would refuse to send data to.
      expect(privacyPolicyUrlFor(''), isNull);
      expect(privacyPolicyUrlFor('http://crm.example.com'), isNull);
    });
  });

  final url = Uri.parse('https://crm.example.com/privacy');

  Future<void> pumpPhone(WidgetTester tester, {Uri? policy}) async {
    final auth = AuthState(store: _Store());
    await auth.load();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
          body: PhoneAccountScreen(auth: auth, privacyPolicyUrl: policy)),
    ));
    await tester.pump();
  }

  Future<void> pumpDesktop(WidgetTester tester, {Uri? policy}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: Center(child: AccountDialog(privacyPolicyUrl: policy))),
    ));
    await tester.pump();
  }

  testWidgets('phone: the account screen links to the policy', (tester) async {
    await pumpPhone(tester, policy: url);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('phone: a build with no server shows no dead link', (tester) async {
    await pumpPhone(tester);
    expect(find.text('Privacy policy'), findsNothing);
  });

  testWidgets('desktop: the account dialog links to the policy', (tester) async {
    await pumpDesktop(tester, policy: url);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('desktop: a build with no server shows no dead link',
      (tester) async {
    await pumpDesktop(tester);
    expect(find.text('Privacy policy'), findsNothing);
  });
}
