/// Deployment config. ⚠ Edit these two values after the VPS is up, then
/// rebuild. Deliberately a constant rather than a settings screen — settings
/// screens for things that could just be a decision are scope.
///
/// Until syncBaseUrl is non-empty, the app is purely local and the sidebar
/// says so. Nothing else changes; sync is not on the critical path.
const kSyncBaseUrl = '';           // e.g. 'https://crm.example.com'

// ⚠ There is no token constant here any more. It used to be a shared secret
// compiled into the app, which meant the same string sat in a public
// repository, in every build, and could only be rotated by rebuilding both
// clients. The token now comes from signing in and lives in the Keychain /
// Android Keystore — see domain/auth.dart.

/// ⚠ https only. The token rides in an Authorization header on every request,
/// so over plain http it is readable by anyone on the network — and phone sync
/// happens on cafe and airport wifi, which is the whole reason the phone
/// client exists. Caddy gives you TLS for free; there is no reason to be on
/// http, so a misconfigured http:// URL disables sync rather than leaking.
bool get kSyncEnabled => syncEnabledFor(kSyncBaseUrl);

/// Split out so the rule above is testable without rebuilding with a real URL.
bool syncEnabledFor(String baseUrl) =>
    baseUrl.isNotEmpty && baseUrl.startsWith('https://');
