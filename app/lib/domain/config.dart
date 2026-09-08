/// Deployment config. ⚠ Edit these two values after the VPS is up, then
/// rebuild. Deliberately a constant rather than a settings screen — settings
/// screens for things that could just be a decision are scope.
///
/// Until syncBaseUrl is non-empty, the app is purely local and the sidebar
/// says so. Nothing else changes; sync is not on the critical path.
const kSyncBaseUrl = '';           // e.g. 'https://crm.example.com'
const kSyncToken = 'dev-token-change-me';

bool get kSyncEnabled => kSyncBaseUrl.isNotEmpty;
