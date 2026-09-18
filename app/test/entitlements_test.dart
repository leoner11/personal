import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// ⚠ The Mac app must reach the network, and must NOT claim entitlements that
/// force real signing. It is sandboxed and ad-hoc signed so its zip runs on
/// anyone's Mac; adding keychain-access-groups makes the build demand a
/// development certificate, which is how this broke once already. macOS keeps
/// its token in a file instead — see TokenStore.
void main() {
  for (final f in ['macos/Runner/Release.entitlements',
                   'macos/Runner/DebugProfile.entitlements']) {
    test('$f keeps the app networkable and ad-hoc signable', () {
      final xml = File(f).readAsStringSync();
      expect(xml, isNot(contains('keychain-access-groups')),
          reason: 'this entitlement forces development signing, breaking '
              'the zips people download');
      expect(xml, contains('com.apple.security.network.client'),
          reason: 'no outgoing network — sync and sign-in cannot reach the server');
    });
  }
}
