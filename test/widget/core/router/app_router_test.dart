import 'package:agentic/core/router/app_router.dart';
import 'package:agentic/features/auth/domain/entities/identity.dart';
import 'package:agentic/features/auth/domain/repositories/auth_repository.dart';
import 'package:agentic/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:agentic/features/auth/presentation/pages/login_page.dart';
import 'package:agentic/features/bots/domain/entities/bot.dart';
import 'package:agentic/features/bots/domain/repositories/bots_repository.dart';
import 'package:agentic/features/bots/presentation/pages/bot_detail_page.dart';
import 'package:agentic/features/bots/presentation/pages/bots_list_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockBotsRepo extends Mock implements BotsRepository {}

const _identity = Identity(userId: 'u1', orgId: 'o1', role: 'OWNER');

Widget _host(AppRouter router, AuthBloc authBloc) =>
    BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp.router(routerConfig: router.router),
    );

void main() {
  late _MockAuthBloc authBloc;
  late _MockBotsRepo botsRepo;
  late AppRouter router;

  setUp(() {
    authBloc = _MockAuthBloc();
    botsRepo = _MockBotsRepo();
    // El BotsBloc de la ruta /home arranca con LoadRequested al construirse;
    // el repo mock devuelve una lista vacía para que el load termine sin
    // colgar el pumpAndSettle.
    when(botsRepo.list).thenAnswer((_) async => const <Bot>[]);
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
    );
  });

  testWidgets('AuthInitial → Splash (CircularProgressIndicator)', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthInitial());

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AuthAuthenticated → /home muestra BotsListPage', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();

    expect(find.byType(BotsListPage), findsOneWidget);
  });

  testWidgets('AuthUnauthenticated → redirige a LoginPage', (tester) async {
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets(
    'cambio de estado dispara refreshListenable y re-evalúa redirect',
    (tester) async {
      whenListen(
        authBloc,
        Stream<AuthState>.fromIterable(const <AuthState>[
          AuthUnauthenticated(),
          AuthAuthenticated(_identity),
        ]),
        initialState: const AuthInitial(),
      );

      await tester.pumpWidget(_host(router, authBloc));
      await tester.pumpAndSettle();
      expect(find.byType(BotsListPage), findsOneWidget);
    },
  );

  testWidgets('AuthAuthenticated → /bots/:id muestra BotDetailPage', (
    tester,
  ) async {
    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_identity));
    // El BotDetailBloc de la ruta arranca con LoadRequested al construirse;
    // el repo mock devuelve un Bot para que el load termine sin colgar
    // pumpAndSettle.
    when(() => botsRepo.byId('b1')).thenAnswer(
      (_) async => const Bot(
        id: 'b1',
        orgId: 'o1',
        templateId: 't1',
        name: 'Soporte',
        channel: BotChannel.waUnofficial,
        identifier: '52155...',
        version: 3,
        paused: false,
        aiDisabled: false,
      ),
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/bots/b1');
    await tester.pumpAndSettle();

    expect(find.byType(BotDetailPage), findsOneWidget);
    verify(() => botsRepo.byId('b1')).called(1);
  });

  testWidgets('AuthUnauthenticated + ruta protegida cualquiera → /login', (
    tester,
  ) async {
    // El redirect no debe asumir que /home es el único destino protegido:
    // cualquier ruta no pública (p. ej. /bots/:id por deep-link) tiene que
    // mandar a /login si no hay sesión.
    when(() => authBloc.state).thenReturn(const AuthUnauthenticated());
    router = AppRouter(
      authBloc: authBloc,
      authRepository: _MockAuthRepo(),
      botsRepository: botsRepo,
    );

    await tester.pumpWidget(_host(router, authBloc));
    await tester.pumpAndSettle();
    router.router.go('/bots/b1');
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(BotDetailPage), findsNothing);
  });
}
