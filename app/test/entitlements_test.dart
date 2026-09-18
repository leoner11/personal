import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// ⚠ WHY THIS EXISTS. The sandboxed Mac app stores its sign-in token in the
/// keychain, which a sandboxed app may only do with this entitlement. Without
/// it the server created the account, saving the token threw, and the app said
/// nothing and stayed signed out — for a whole day. Nothing else in the build
/// notices; a release just quietly cannot sign in.
void main() {
  for (final f in ['macos/Runner/Release.entitlements',
                   'macos/Runner/DebugProfile.entitlements']) {
    test('$f lets the app use the keychain and the network', () {
      final xml = File(f).readAsStringSync();
      expect(xml, contains('keychain-access-groups'),
          reason: 'no keychain entitlement — sign-in cannot persist');
      expect(xml, contains(r'$(AppIdentifierPrefix)com.mjcxstudio.personalCrm'));
      expect(xml, contains('com.apple.security.network.client'),
          reason: 'no outgoing network — sync and sign-in cannot reach the server');
    });
  }
}
