import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/config/bangumi_mirror_route.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/crypto.dart';

class BangumiClient {
  BangumiClient._();

  static final BangumiClient instance = BangumiClient._();

  Future<dynamic> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    String? accessToken,
    CancelToken? cancelToken,
  }) async {
    try {
      final first = await _sendGet(
        url,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        accessToken: accessToken,
        cancelToken: cancelToken,
      );
      if (!_shouldRescueUnsignedCommentBody(url, first.data)) {
        return first.data;
      }
      KazumiLogger().i(
        'Bangumi mirror: unsigned host has no next comments, retry official next API with ECH',
      );
    } on DioException catch (e) {
      if (!_shouldRescueUnsignedCommentError(url, e)) {
        throw await NetworkErrorMapper.mapException(e);
      }
      KazumiLogger().i(
        'Bangumi mirror: unsigned host rejected next comments, retry official next API with ECH',
      );
    }

    try {
      final rescued = await _sendGet(
        url,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
        accessToken: accessToken,
        cancelToken: cancelToken,
        extra: const {bangumiBypassMirrorRewriteExtra: true},
      );
      return rescued.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Future<Response<dynamic>> _sendGet(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    String? accessToken,
    CancelToken? cancelToken,
    Map<String, dynamic>? extra,
  }) {
    return DioFactory.bangumiDio.get<dynamic>(
      url,
      queryParameters: queryParameters,
      options: Options(
        headers: _headers(
          requiresAuth: requiresAuth,
          accessToken: accessToken,
          url: url,
          method: 'GET',
        ),
        extra: extra,
      ),
      cancelToken: cancelToken,
    );
  }

  Future<dynamic> post(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await DioFactory.bangumiDio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          headers: _headers(
            requiresAuth: requiresAuth,
            url: url,
            method: 'POST',
            data: data,
          ),
        ),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (e) {
      throw await NetworkErrorMapper.mapException(e);
    }
  }

  Map<String, dynamic> _headers({
    required bool requiresAuth,
    String? accessToken,
    required String url,
    required String method,
    Object? data,
  }) {
    final headers = <String, dynamic>{...bangumiHTTPHeader};
    final bangumiSyncEnable = GStorage.getSetting(
      SettingsKeys.bangumiSyncEnable,
    );
    final token =
        (accessToken ??
                GStorage.getSetting<String>(SettingsKeys.bangumiAccessToken))
            .trim();
    if ((requiresAuth || bangumiSyncEnable) && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (_shouldSignProtectedMirrorRequest(url, method)) {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final body = data == null ? '' : jsonEncode(data);
      headers['X-AppId'] = bangumiMirrorCredentials['id'];
      headers['X-Timestamp'] = timestamp;
      headers['X-Signature'] = generateBangumiMirrorSearchSignature(
        method: method,
        path: Uri.parse(url).path,
        body: body,
        timestamp: timestamp,
      );
    }
    return headers;
  }

  bool _shouldSignProtectedMirrorRequest(String url, String method) {
    if (!hasBangumiMirrorCredentials) {
      return false;
    }
    final uri = Uri.parse(url);
    if (BangumiAcceleration.current != BangumiAcceleration.mirror ||
        !ApiEndpoints.bangumiPublicApiHosts.contains(uri.host)) {
      return false;
    }
    return isSignatureProtectedBangumiRequest(method, uri.path);
  }

  bool _unsignedCommentRescueEligible(String url) {
    if (hasBangumiMirrorCredentials) {
      return false;
    }
    if (BangumiAcceleration.current != BangumiAcceleration.mirror) {
      return false;
    }
    final uri = Uri.parse(url);
    return ApiEndpoints.bangumiPublicApiHosts.contains(uri.host) &&
        isBangumiNextCommentPath(uri.path);
  }

  bool _shouldRescueUnsignedCommentBody(String url, dynamic data) {
    return _unsignedCommentRescueEligible(url) &&
        isUnsignedMirrorCommentMiss(data);
  }

  bool _shouldRescueUnsignedCommentError(String url, DioException error) {
    if (error.requestOptions.extra[bangumiBypassMirrorRewriteExtra] == true) {
      return false;
    }
    if (!_unsignedCommentRescueEligible(url)) {
      return false;
    }
    if (error.response?.statusCode == 404) {
      return true;
    }
    return isUnsignedMirrorCommentMiss(error.response?.data);
  }
}
