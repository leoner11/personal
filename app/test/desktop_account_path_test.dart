import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_crm/data/database.dart';
import 'package:personal_crm/domain/auth.dart';
import 'package:personal_crm/theme/tokens.dart';
import 'package:personal_crm/ui/shell.dart';
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

/// ⚠ The Mac has no "Account" item in the sidebar: the ONLY way to reach
/// sign-in is the small status line in the sidebar's bottom corner. If that
/// line stops saying so, or stops opening the panel, a new Mac user has no way
/// to create an account at all.
void main() {
  testWidgets('the sidebar offers sign-in, and opens the account panel',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final auth = AuthState(store: _Store());
    await auth.load();
    appAuth = auth;
    addTearDown(() => appAuth = null);

    await tester.pumpWidget(
        MaterialApp(theme: buildTheme(Brightness.light), home: Shell(db: db)));
    await tester.pump(const Duration(milliseconds: 100));

    // Signed out, with a server configured: the line says what to do.
    expect(find.text('Sign in to sync'), findsOneWidget);

    await tester.tap(find.text('Sign in to sync'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The panel that can both sign in and create an account.
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
  });
}
