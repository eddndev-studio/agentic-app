import 'package:agentic/features/auth/data/datasources/auth_datasource.dart';
import 'package:agentic/features/auth/domain/entities/auth_tokens.dart';
import 'package:agentic/features/auth/domain/failures/auth_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late DioAuthDatasource ds;

  setUp(() {
    dio = _MockDio();
    ds = DioAuthDatasource(dio);
  });

  Response<Map<String, dynamic>> resp(
    int status, {
    Map<String, dynamic>? body,
  }) => Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/auth/login'),
    statusCode: status,
    data: body,
  );

  group('DioAuthDatasource.login', () {
    test('200 con par de tokens → AuthTokens', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any<Object?>(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => resp(
          200,
          body: <String, dynamic>{
            'access_token': 'a.b.c',
            'refresh_token': 'r-32',
            'token_type': 'Bearer',
            'expires_in': 900,
          },
        ),
      );

      final tokens = await ds.login(
        email: 'op@example.com',
        password: 'hunter2-secret',
      );

      expect(
        tokens,
        const AuthTokens(
          accessToken: 'a.b.c',
          refreshToken: 'r-32',
          tokenType: 'Bearer',
          expiresInSeconds: 900,
        ),
      );
      verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: <String, dynamic>{
            'email': 'op@example.com',
            'password': 'hunter2-secret',
          },
        ),
      ).called(1);
    });

    test('401 → InvalidCredentialsFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: resp(401),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        ds.login(email: 'x@y.z', password: 'bad'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
    });

    test('429 → RateLimitedFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: resp(429),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        ds.login(email: 'x@y.z', password: 'p'),
        throwsA(isA<RateLimitedFailure>()),
      );
    });

    test('timeout de red → NetworkFailure', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectLater(
        ds.login(email: 'x@y.z', password: 'p'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('500 → UnknownAuthFailure (no se filtra el status crudo)', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any<Object?>(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: resp(500),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        ds.login(email: 'x@y.z', password: 'p'),
        throwsA(isA<UnknownAuthFailure>()),
      );
    });
  });
}
