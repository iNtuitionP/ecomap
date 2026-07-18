// T5 · recognition-flow — 수동 선택 화면 위젯 테스트.
//
// 검증: (1) 8카테고리 그리드 렌더(라벨은 mapping.json 단일 소스),
// (2) 셀 탭 → /result/:id?manual=1 라우팅, (3) manual=1 이벤트 로깅
// (manualFallback=true, csvFlag는 매핑 산출값), (4) conf 쿼리 → 주황 칩.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecomap/core/router.dart';
import 'package:ecomap/core/theme/app_theme.dart';
import 'package:ecomap/data/events_api.dart';
import 'package:ecomap/data/providers.dart';

import 'scan_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // install_id 영속(T7)이 SharedPreferences를 쓰므로 테스트 목킹 필수.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final mapping = loadMappingFromDisk();

  /// ListView 하단(뷰포트 밖)의 위젯을 스크롤로 드러낸다.
  Future<void> revealInList(WidgetTester tester, Finder finder) async {
    await tester.dragUntilVisible(
      finder,
      find.byType(ListView).first,
      const Offset(0, -140),
    );
    await tester.pumpAndSettle();
  }

  Future<(GoRouter, InMemoryEventLogger)> pumpSelect(
    WidgetTester tester, {
    String location = '/select',
  }) async {
    final logger = InMemoryEventLogger();
    final container = ProviderContainer(
      overrides: [
        // FakeAsync에서 rootBundle 로드가 멈추는 문제 회피 — 동기 파일 번들.
        assetBundleProvider.overrideWithValue(SyncFileAssetBundle()),
        eventLoggerProvider.overrideWithValue(logger),
      ],
    );
    addTearDown(container.dispose);
    final router = createAppRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildAppTheme(),
          routerConfig: router,
        ),
      ),
    );
    router.go(location);
    await tester.pumpAndSettle();
    return (router, logger);
  }

  testWidgets('직접 진입: 8카테고리 그리드가 mapping 라벨로 전부 렌더된다', (tester) async {
    await pumpSelect(tester);

    expect(find.text('품목 직접 선택'), findsOneWidget);
    expect(find.text('직접 골라주세요'), findsOneWidget);
    expect(find.text('이 품목이 무엇에 가까운가요?'), findsOneWidget);

    // 8칸 전부 — 라벨은 mapping.json 단일 소스에서.
    expect(mapping.categories, hasLength(8));
    for (final category in mapping.categories) {
      expect(
        find.byKey(ValueKey('category-cell-${category.id}')),
        findsOneWidget,
        reason: '${category.id} 셀 누락',
      );
      expect(find.text(category.label), findsWidgets,
          reason: '${category.label} 라벨 누락');
    }

    // 직접 진입에는 저신뢰 칩 없음.
    expect(find.textContaining('잘 모르겠어요'), findsNothing);

    // 하단 안내 캡션은 스크롤로 드러난다.
    final hint = find.text('참고 · 신뢰도 높으면 자동 인식');
    await revealInList(tester, hint);
    expect(hint, findsOneWidget);
  });

  testWidgets('conf 쿼리 진입: 주황 칩(잘 모르겠어요 · NN%)로 진입 사유 표시', (tester) async {
    await pumpSelect(tester, location: '/select?conf=0.41');

    expect(find.text('촬영 결과'), findsOneWidget);
    expect(find.text('잘 모르겠어요 · 41%'), findsOneWidget);
    expect(find.text('신뢰도 낮음'), findsOneWidget);
  });

  testWidgets('셀 탭 → /result/:id?manual=1 + manualFallback=true 로깅',
      (tester) async {
    final (_, logger) = await pumpSelect(tester);

    final category = mapping.categories.first;
    await tester.tap(find.byKey(ValueKey('category-cell-${category.id}')));
    await tester.pumpAndSettle();

    // 결과 화면으로 이동 — 수동 선택 배지(신뢰도 없음) + '직접 선택' 라벨.
    expect(find.text('인식 결과'), findsOneWidget);
    expect(find.text('✓ ${category.label}'), findsOneWidget);
    expect(find.text('직접 선택'), findsOneWidget);
    expect(find.text('이렇게 버리세요'), findsOneWidget);

    // RECOG_EVENTS 1건 — manual_fallback=true, csvFlag는 매핑 산출값.
    expect(logger.recognitionEvents, hasLength(1));
    final event = logger.recognitionEvents.single;
    expect(event.category, category.id);
    expect(event.csvFlag, category.csvFlags.first);
    expect(event.manualFallback, isTrue);
    expect(event.confidence, 0.0);
  });

  testWidgets('자동 인식 결과(/result?conf=0.96) 진입은 manualFallback=false 로 로깅',
      (tester) async {
    final category = mapping.categories.first;
    final (_, logger) = await pumpSelect(
      tester,
      location: '/result/${category.id}?conf=0.96',
    );

    expect(find.text('✓ ${category.label} · 96%'), findsOneWidget);
    expect(find.text('자동 인식'), findsOneWidget);

    expect(logger.recognitionEvents, hasLength(1));
    final event = logger.recognitionEvents.single;
    expect(event.manualFallback, isFalse);
    expect(event.confidence, closeTo(0.96, 1e-9));
  });
}
