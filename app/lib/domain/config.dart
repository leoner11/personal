/// Deployment config. ⚠ Edit these two values after the VPS is up, then
/// rebuild. Deliberately a constant rather than a settings screen — settings
/// screens for things that could just be a decision are scope.
///
/// Until syncBaseUrl is non-empty, the app is purely local and the sidebar
/// says so. Nothing else changes; sync is not on the critical path.
const kSyncBaseUrl = '';           // e.g. 'https://crm.example.com'

/// ⚠ MUST match SYNC_TOKEN on the server, and MUST NOT stay this value.
/// This default is published in a public repository, so it is a password the
/// whole internet can read. The server refuses to boot with it outside debug;
/// this is the other half of the same pair.
///   SYNC_TOKEN=$(python3 -c 'import secrets;print(secrets.token_urlsafe(32))')
const kSyncToken = 'dev-token-change-me';

/// ⚠ https only. The token rides in an Authorization header on every request,
/// so over plain http it is readable by anyone on the network — and phone sync
/// happens on cafe and airport wifi, which is the whole reason the phone
/// client exists. Caddy gives you TLS for free; there is no reason to be on
/// http, so a misconfigured http:// URL disables sync rather than leaking.
bool get kSyncEnabled => syncEnabledFor(kSyncBaseUrl);

/// Split out so the rule above is testable without rebuilding with a real URL.
bool syncEnabledFor(String baseUrl) =>
    baseUrl.isNotEmpty && baseUrl.startsWith('https://');
