/// 에코지도 찌릿 — 앱 진입점.
///
/// Riverpod ProviderScope + go_router(MaterialApp.router) + Material3 테마.
///
/// 이벤트 로거는 플랫폼별로 배선한다 — 모바일/데스크톱은 SQLite
/// (RECOG_EVENTS·POINT_LOGS, SPEC T7), 웹은 인메모리 폴백.
/// 분기는 [createEventLogger]가 kIsWeb으로 내부 처리한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'services/events/sqlite_event_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 웹(kIsWeb) → InMemoryEventLogger, 그 외 → SqliteEventLogger.
  final eventLogger = await createEventLogger();
  runApp(
    ProviderScope(
      overrides: [eventLoggerProvider.overrideWithValue(eventLogger)],
      child: const EcoMapApp(),
    ),
  );
}

/// 루트 앱 위젯. 라우터는 인스턴스별로 생성해 테스트 간 상태 공유를 막는다.
class EcoMapApp extends StatefulWidget {
  const EcoMapApp({super.key});

  @override
  State<EcoMapApp> createState() => _EcoMapAppState();
}

class _EcoMapAppState extends State<EcoMapApp> {
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '에코지도 찌릿',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
