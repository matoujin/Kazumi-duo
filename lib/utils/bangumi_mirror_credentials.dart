// Bangumi mirror API credentials for the search signature flow.
// Release/PR CI injects them via --dart-define=KAZUMI_APPID / KAZUMI_KEY.
const Map<String, String> bangumiMirrorCredentials = {
  'id': String.fromEnvironment('KAZUMI_APPID'),
  'value': String.fromEnvironment('KAZUMI_KEY'),
};

/// Duo CI builds often omit both defines. Empty strings must not be treated
/// as a usable signing identity.
bool get hasBangumiMirrorCredentials {
  final id = bangumiMirrorCredentials['id'] ?? '';
  final value = bangumiMirrorCredentials['value'] ?? '';
  return id.isNotEmpty && value.isNotEmpty;
}
