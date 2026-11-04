import 'package:kazumi/request/config/api_endpoints.dart';

/// Set on a follow-up request that must keep the original public host.
/// The acceleration interceptor then enables ECH instead of rewriting it.
const String bangumiBypassMirrorRewriteExtra = 'bangumiBypassMirrorRewrite';

/// Search and next-API comments are the Bangumi routes api.kazumi.fyi signs.
bool isSignatureProtectedBangumiRequest(String method, String path) {
  final normalized = method.toUpperCase();
  if (normalized == 'POST' && path == '/v0/search/subjects') {
    return true;
  }
  if (normalized != 'GET') {
    return false;
  }
  return isBangumiNextCommentPath(path);
}

bool isBangumiNextCommentPath(String path) {
  return (path.startsWith('/p1/subjects/') && path.endsWith('/comments')) ||
      (path.startsWith('/p1/episodes/') && path.endsWith('/comments')) ||
      (path.startsWith('/p1/characters/') && path.endsWith('/comments'));
}

/// api.bgmapi.com answers unknown routes, including all of /p1, with HTTP 200
/// and `{"code":404,"error":"Not Found"}`. That is not a comment payload.
bool isUnsignedMirrorCommentMiss(dynamic data) {
  if (data is! Map) {
    return false;
  }
  if (data['data'] is List || data['list'] is List) {
    return false;
  }
  final code = data['code'];
  if (code != 404 && code != '404') {
    return false;
  }
  final error = data['error'];
  return error != null && error.toString().isNotEmpty;
}

/// Signed mirror stays on api.kazumi.fyi. Without credentials, the routes
/// that mirror rejects with HTTP 401 go to the unsigned api.bgmapi.com host.
String bangumiMirrorOrigin({
  required bool credentialsPresent,
  required String method,
  required String path,
}) {
  if (!credentialsPresent && isSignatureProtectedBangumiRequest(method, path)) {
    return ApiEndpoints.bangumiAuthAPIMirrorDomain;
  }
  return ApiEndpoints.bangumiMirrorDomain;
}
