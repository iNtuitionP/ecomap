// T6 CRITICAL · SPEC T6-2 — /map/styrofoam 진입 시 빈 지도 크래시 없이
// /gap/styrofoam 자동 리다이렉트 (styrofoam @ 철산역 = TooFarGap 실데이터).
//
// 실제 앱 라우터(createAppRouter)로 리다이렉트·역방향(위치 보기) 흐름을 검증한다.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ecomap/core/router.dart';
import 'package:ecomap/core/theme/app_theme.dart';
import 'package:ecomap/data/bins_repository.dart';
import 'package:ecomap/data/events_api.dart';
import 'package:ecomap/data/models.dart';
import 'package:ecomap/data/providers.dart';
import 'package:ecomap/features/map/gap_screen.dart';
import 'package:ecomap/features/map/map_screen.dart';
import 'package:ecomap/shared/mapping_loader.dart';

// 위젯 테스트 본문은 FakeAsync 존이라 대용량 에셋 로드(isolate 디코드)가
// 완료되지 않는다 — setUpAll(실 async)에서 미리 로드해 프로바이더를 덮는다.
late List<BinRecord> bins;
late RecycleMapping mapping;

Widget _app(GoRouter router, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      mapTileLayerProvider.overrideWithValue(const SizedBox.shrink()),
      binsProvider.overrideWith((ref) async => bins),
      mappingProvider.overrideWith((ref) async => mapping),
      ...overrides,
    ],
    child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    bins = await BinsRepository().loadBins();
    mapping = await MappingLoader().loadMapping();
  });

  testWidgets('[CRITICAL] /map/styrofoam → 크래시·빈 지도 없이 gap 화면(일직동) 렌더',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = createAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    router.go('/map/styrofoam');
    await tester.pumpAndSettle();

    expect(find.byType(GapScreen), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);
    expect(find.textContaining('받는 곳이 없어요'), findsOneWidget);
    expect(find.textContaining('일직동', findRichText: true), findsWidgets);
    expect(find.text('도보 96분 · 6.4km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gap → [일직동 위치 보기] → 포커스 좌표로 /map 이동 (재리다이렉트 루프 없음)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = createAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    router.go('/gap/styrofoam');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('일직동 위치 보기'));
    await tester.tap(find.text('일직동 위치 보기'));
    await tester.pumpAndSettle();

    // 포커스 진입 — gap으로 되돌아가지 않고 지도 유지.
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(GapScreen), findsNothing);
    expect(find.byType(FlutterMap), findsOneWidget);
    // styrofoam Y 거점은 물리 4곳이지만 표시용 그룹핑(동일 이름·주소·타입 합침)
    // 으로 2행: 일직동 505-20 ×2, 505-11 ×2 — 각 행에 '2개' 배지.
    expect(find.byType(BinListTile), findsNWidgets(2));
    expect(find.text('2개'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('gap [알리기] → eventLogger 적재 후에도 라우팅 정상', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final logger = InMemoryEventLogger();
    final router = createAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
        _app(router, overrides: [eventLoggerProvider.overrideWithValue(logger)]));
    router.go('/gap/styrofoam');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('이 사각지대를 광명시에 알리기'));
    await tester.tap(find.text('이 사각지대를 광명시에 알리기'));
    await tester.pumpAndSettle();

    expect(logger.civicReports, hasLength(1));
    expect(
      find.textContaining('알린 내용은 시 정책 데이터로 반영됩니다'),
      findsOneWidget,
    );
  });
}
