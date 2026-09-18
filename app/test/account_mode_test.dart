import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/domain/auth.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/account_dialog.dart';
import 'package:personal_crm/ui/phone/account_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store implements TokenStore {
  @override
  Future<String?> token() async => null;
  @override
  Future<String?> username() async => null;
  @override
  Future<void> save(String t, String u) async {}
  @override
  Future<void> clear() async {}
}

/// ⚠ WHY THIS EXISTS. Signing up on the Mac silently did nothing: the ghost
/// button said "Create an account" but only SWITCHED modes, while the button
/// that submits said "Sign in". Pressing the ghost looked like a no-op, the
/// account was never created, and signing in afterwards failed. The mode must
/// be stated on screen, not implied by a button label.
void main() {
  late AuthState auth;

  Future<void> pump(WidgetTester tester, Widget child, Size size) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    auth = AuthState(store: _Store());
    await auth.load();
    appAuth = auth;
    addTearDown(() => appAuth = null);
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light), home: Scaffold(body: child)));
    await tester.pump();
  }

  for (final (name, child, size) in [
    ('desktop', const AccountDialog(), const Size(1280, 900)),
    ('phone', null, const Size(1170, 2532)),
  ]) {
    testWidgets('$name: the form says which mode it is in, and switching says so',
        (tester) async {
      await pump(
          tester,
          child ?? PhoneAccountScreen(auth: AuthState(store: _Store())),
          size);

      // Signing in is the default, and the submit button agrees with the
      // heading: "Sign in" submits, "Create an account" only switches modes.
      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Create account'), findsNothing);
      expect(find.text('Create an account'), findsOneWidget);

      await tester.tap(find.text('Create an account').first);
      await tester.pump();

      // ⚠ The heading changes, not just the button — that was the whole bug.
      // ⚠ The heading changes to match, not just the submit button — that
      // was the whole bug.
      expect(find.text('Create an account'), findsOneWidget); // now the heading
      expect(find.text('Create account'), findsOneWidget); // submits
      expect(find.text('I already have an account'), findsOneWidget);
    });
  }
}
