import 'package:ataulfo/core/design/app_design_theme.dart';
import 'package:ataulfo/core/design/widgets/app_avatar.dart';
import 'package:ataulfo/features/profile/domain/entities/chat_profile.dart';
import 'package:ataulfo/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:ataulfo/features/profile/presentation/widgets/chat_thread_app_bar.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

void main() {
  late _MockProfileBloc bloc;
  setUp(() {
    bloc = _MockProfileBloc();
    when(() => bloc.state).thenReturn(const ProfileInitial());
  });

  Widget host() => MaterialApp(
    theme: AppDesignTheme.dark(),
    home: BlocProvider<ProfileBloc>.value(
      value: bloc,
      child: const Scaffold(
        appBar: ChatThreadAppBar(botId: 'b1', chatLid: 'lid-dm'),
        body: SizedBox.shrink(),
      ),
    ),
  );

  testWidgets('cargado muestra el nombre real + avatar', (tester) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'lid-dm',
          isGroup: false,
          phone: '521555',
          displayName: 'Alice',
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(AppAvatar), findsOneWidget);
  });

  testWidgets('mientras carga cae al chatLid (no bloquea el header)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProfileLoading());
    await tester.pumpWidget(host());
    expect(find.text('lid-dm'), findsOneWidget);
  });

  testWidgets('el header es tappable (InkWell para abrir el perfil)', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const ProfileLoading());
    await tester.pumpWidget(host());
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('GROUP sin displayName cae a "Grupo"', (tester) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'g@g.us',
          isGroup: true,
          phone: null,
          displayName: null,
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('Grupo'), findsOneWidget);
  });

  testWidgets('DM sin displayName cae al phone', (tester) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'lid-dm',
          isGroup: false,
          phone: '521555',
          displayName: null,
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('521555'), findsOneWidget);
  });

  testWidgets('el header se anuncia como botón con hint "Ver perfil"', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      const ProfileLoaded(
        ChatProfile(
          chatLid: 'lid-dm',
          isGroup: false,
          phone: '521555',
          displayName: 'Alice',
          photoUrl: null,
          isArchived: false,
          isPinned: false,
          isMarkedUnread: false,
          mutedUntil: null,
        ),
      ),
    );
    await tester.pumpWidget(host());
    final sem = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.hint == 'Ver perfil',
      ),
    );
    expect(sem.properties.button, isTrue);
    expect(sem.properties.label, 'Alice');
  });
}
