import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/request/clients/bangumi_client.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/network/bangumi_acceleration.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory directory;
  late PathProviderPlatform originalPathProvider;
  late _BangumiAdapter adapter;

  setUpAll(() async {
    Logger.level = Level.off;
    directory = await Directory.systemTemp.createTemp('kazumi_mirror_test_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    Hive.init(directory.path);
    await GStorage.init();
  });

  setUp(() async {
    expect(hasBangumiMirrorCredentials, isFalse);
    await GStorage.putSetting(SettingsKeys.bangumiSyncEnable, false);
    await GStorage.putSetting(SettingsKeys.bangumiAccessToken, '');
    await GStorage.putSetting(
      SettingsKeys.bangumiAcceleration,
      BangumiAcceleration.mirror.name,
    );
    await GStorage.putSetting(SettingsKeys.enableBangumiProxy, true);
    DioFactory.reset();
    adapter = _BangumiAdapter();
    DioFactory.bangumiDio.httpClientAdapter.close();
    DioFactory.bangumiDio.httpClientAdapter = adapter;
  });

  tearDownAll(() async {
    DioFactory.bangumiDio.close(force: true);
    DioFactory.reset();
    await Hive.close();
    PathProviderPlatform.instance = originalPathProvider;
    await directory.delete(recursive: true);
  });

  test(
    'mirror search without credentials uses unsigned host and no signature',
    () async {
      await BangumiClient.instance.post(
        'https://api.bgm.tv/v0/search/subjects?limit=20&offset=0',
        data: {'keyword': '孤独摇滚'},
      );

      final request = adapter.requests.single;
      expect(
        request.uri,
        Uri.parse(
          'https://api.bgmapi.com/v0/search/subjects?limit=20&offset=0',
        ),
      );
      expect(_header(request, 'x-signature'), isNull);
      expect(_header(request, 'x-appid'), isNull);
      expect(_header(request, 'x-timestamp'), isNull);
    },
  );

  test('direct search stays on the official host', () async {
    await GStorage.putSetting(
      SettingsKeys.bangumiAcceleration,
      BangumiAcceleration.direct.name,
    );

    await BangumiClient.instance.post(
      'https://api.bgm.tv/v0/search/subjects?limit=5&offset=0',
      data: {'keyword': '测试'},
    );

    expect(adapter.requests.single.uri.host, 'api.bgm.tv');
    expect(_header(adapter.requests.single, 'x-signature'), isNull);
  });

  test('mirror subject metadata still uses the signed mirror host', () async {
    await BangumiClient.instance.get('https://next.bgm.tv/p1/subjects/12');

    expect(adapter.requests.single.uri.host, 'api.kazumi.fyi');
    expect(adapter.requests.single.uri.path, '/p1/subjects/12');
  });

  test(
    'next comments fall back to bgmapi, then ECH when that mirror 404s',
    () async {
      adapter.respond = (request) async {
        if (request.uri.host == 'api.bgmapi.com') {
          return _json({
            'request': request.uri.path,
            'code': 404,
            'error': 'Not Found',
          });
        }
        return _json({'data': <Object>[], 'total': 0});
      };

      final data = await BangumiClient.instance.get(
        'https://next.bgm.tv/p1/subjects/12/comments?limit=20&offset=0',
      );

      expect(data, {'data': <Object>[], 'total': 0});
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.first.uri,
        Uri.parse(
          'https://api.bgmapi.com/p1/subjects/12/comments?limit=20&offset=0',
        ),
      );
      expect(_header(adapter.requests.first, 'x-signature'), isNull);
      expect(adapter.requests.last.uri.host, 'next.bgm.tv');
      expect(adapter.requests.last.uri.path, '/p1/subjects/12/comments');
      expect(adapter.requests.last.extra['ech'], isTrue);
    },
  );

  test(
    'episode and character comments use the same unsigned fallback',
    () async {
      adapter.respond = (request) async {
        if (request.uri.host == 'api.bgmapi.com') {
          return _json({'code': 404, 'error': 'Not Found'});
        }
        return _json(<Object>[]);
      };

      for (final url in [
        'https://next.bgm.tv/p1/episodes/8/comments',
        'https://next.bgm.tv/p1/characters/1/comments',
      ]) {
        adapter.requests.clear();
        await BangumiClient.instance.get(url);
        expect(adapter.requests.first.uri.host, 'api.bgmapi.com');
        expect(adapter.requests.last.uri.host, 'next.bgm.tv');
        expect(adapter.requests.last.extra['ech'], isTrue);
      }
    },
  );

  test(
    'HTTP 404 from the unsigned mirror also retries next comments',
    () async {
      adapter.respond = (request) async {
        if (request.uri.host == 'api.bgmapi.com') {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: request,
              statusCode: 404,
              data: {'code': 404, 'error': 'Not Found'},
            ),
          );
        }
        return _json(<Object>[]);
      };

      await BangumiClient.instance.get(
        'https://next.bgm.tv/p1/episodes/8/comments',
      );

      expect(adapter.requests.map((request) => request.uri.host), [
        'api.bgmapi.com',
        'next.bgm.tv',
      ]);
    },
  );

  test('a real unsigned comment payload is not retried', () async {
    adapter.respond = (_) async => _json({'data': <Object>[], 'total': 0});

    await BangumiClient.instance.get(
      'https://next.bgm.tv/p1/subjects/12/comments?limit=20&offset=0',
    );

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.uri.host, 'api.bgmapi.com');
  });
}

String? _header(RequestOptions request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name) {
      return entry.value?.toString();
    }
  }
  return null;
}

ResponseBody _json(Object data, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _BangumiAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Future<ResponseBody> Function(RequestOptions) respond = (_) async =>
      _json({'ok': true});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
