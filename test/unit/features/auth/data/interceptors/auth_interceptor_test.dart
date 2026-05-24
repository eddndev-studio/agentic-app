import 'dart:convert';

import 'package:agentic/core/storage/secure_kv_store.dart';
import 'package:agentic/features/auth/data/datasources/auth_datasource.dart';
import 'package:agentic/features/auth/data/interceptors/auth_interceptor.dart';
import 'package:agentic/features/auth/data/repositories/token_storage.dart';
import 'package:agentic/features/auth/domain/entities/auth_tokens.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// SecureKvStore en memoria — los tests del interceptor no necesitan
/// Keystore real; TokenStorage por encima sigue siendo el real.
class _MemKv implements SecureKvStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

class _MockAuthDs extends Mock implements AuthDatasource {}

typedef _Handler = Future<ResponseBody> Function(RequestOptions);

/// Adapter HTTP fake: intercepta lo que Dio dispara realmente al transporte
/// (después de los interceptors). Permite afirmar headers del request final
/// y simular respuestas/errores sin tocar red.
class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter(this._handler);

  _Handler _handler;
  final List<RequestOptions> captured = <RequestOptions>[];

  set handler(_Handler h) => _handler = h;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) {
    captured.add(options);
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(int status, Map<String, dynamic> json) =>
    ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: const <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );

void main() {
  late TokenStorage storage;
  late _MockAuthDs refreshDs;
  late _MockHttpAdapter adapter;
  late Dio dio;
  late int unrecoverableCalls;

  setUp(() {
    storage = TokenStorage(_MemKv());
    refreshDs = _MockAuthDs();
    adapter = _MockHttpAdapter((_) async => _jsonBody(200, <String, dynamic>{}));
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    dio.httpClientAdapter = adapter;
    unrecoverableCalls = 0;
    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        refreshDatasource: refreshDs,
        onUnrecoverable: () async {
          unrecoverableCalls += 1;
        },
      ),
    );
  });

  group('AuthInterceptor.onRequest', () {
    test('con tokens persistidos: agrega Authorization Bearer <access>',
        () async {
      await storage.save(
        const AuthTokens(
          accessToken: 'ACCESS-1',
          refreshToken: 'r',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        ),
      );

      await dio.get<dynamic>('/bots');

      expect(adapter.captured, hasLength(1));
      expect(
        adapter.captured.first.headers['Authorization'],
        'Bearer ACCESS-1',
      );
    });

    test('sin tokens persistidos: no agrega Authorization', () async {
      await dio.get<dynamic>('/health');

      expect(adapter.captured, hasLength(1));
      expect(
        adapter.captured.first.headers.containsKey('Authorization'),
        isFalse,
      );
      // onUnrecoverable NO se invoca por falta de tokens — el interceptor no
      // decide qué ruta exige auth; cualquier 401 posterior lo gestionará.
      expect(unrecoverableCalls, 0);
    });
  });
}
