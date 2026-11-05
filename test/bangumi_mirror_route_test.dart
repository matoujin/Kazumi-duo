import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/request/config/bangumi_mirror_route.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';

void main() {
  test('test builds omit mirror signing credentials', () {
    expect(hasBangumiMirrorCredentials, isFalse);
  });

  test('signed mirror stays on api.kazumi.fyi', () {
    for (final request in _protectedRequests) {
      expect(
        bangumiMirrorOrigin(
          credentialsPresent: true,
          method: request.method,
          path: request.path,
        ),
        ApiEndpoints.bangumiMirrorDomain,
        reason: '${request.method} ${request.path}',
      );
    }
  });

  test(
    'missing credentials send search and next comments to api.bgmapi.com',
    () {
      for (final request in _protectedRequests) {
        expect(
          bangumiMirrorOrigin(
            credentialsPresent: false,
            method: request.method,
            path: request.path,
          ),
          ApiEndpoints.bangumiAuthAPIMirrorDomain,
          reason: '${request.method} ${request.path}',
        );
      }
    },
  );

  test('unsigned fallback does not move routes kazumi.fyi already serves', () {
    for (final request in const [
      (method: 'GET', path: '/v0/subjects/12'),
      (method: 'GET', path: '/v0/episodes'),
      (method: 'GET', path: '/p1/subjects/12'),
      (method: 'GET', path: '/p1/calendar'),
      (method: 'GET', path: '/p1/characters/1'),
      (method: 'POST', path: '/v0/users/-/collections/1'),
    ]) {
      expect(
        bangumiMirrorOrigin(
          credentialsPresent: false,
          method: request.method,
          path: request.path,
        ),
        ApiEndpoints.bangumiMirrorDomain,
        reason: '${request.method} ${request.path}',
      );
    }
  });

  test('unsigned mirror comment miss is the gateway 404 object', () {
    expect(
      isUnsignedMirrorCommentMiss({
        'request': '/p1/subjects/12/comments',
        'code': 404,
        'error': 'Not Found',
      }),
      isTrue,
    );
    expect(
      isUnsignedMirrorCommentMiss({'code': '404', 'error': 'Not Found'}),
      isTrue,
    );
    expect(
      isUnsignedMirrorCommentMiss({'data': <Object>[], 'total': 0}),
      isFalse,
    );
    expect(isUnsignedMirrorCommentMiss(<Object>[]), isFalse);
    expect(
      isUnsignedMirrorCommentMiss({
        'code': 404,
        'error': 'Not Found',
        'data': <Object>[],
      }),
      isFalse,
    );
  });
}

const _protectedRequests = [
  (method: 'POST', path: '/v0/search/subjects'),
  (method: 'post', path: '/v0/search/subjects'),
  (method: 'GET', path: '/p1/subjects/12/comments'),
  (method: 'GET', path: '/p1/episodes/8/comments'),
  (method: 'GET', path: '/p1/characters/1/comments'),
];
