// T6 CRITICAL · 사각지대(공백) 화면 — 목업 ⑤ 재현.
//
// styrofoam @ 철산역 실데이터: Y 거점 4곳 전부 일직동, 최근접 6403.615m
// (> 1500m) → TooFarGap. 도보 96분 · 6.4km (test/data/nearest_service_test.dart
// 수기 대조값과 동일 근거).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/core/theme/app_theme.dart';
import 'package:ecomap/data/bins_repository.dart';
import 'package:ecomap/data/events_api.dart';
import 'package:ecomap/data/models.dart';
import 'package:ecomap/data/providers.dart';
import 'package:ecomap/features/map/gap_screen.dart';
import 'package:ecomap/shared/mapping_loader.dart';

// 위젯 테스트 본문은 FakeAsync 존이라 대용량 에셋 로드(isolate 디코드)가
// 완료되지 않는다 — setUpAll(실 async)에서 미리 로드해 프로바이더를 덮는다.
late List<BinRecord> bins;
late RecycleMapping mapping;

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  RecycleMapping? mappingOverride,
}) {
  return ProviderScope(
    overrides: [
      binsProvider.overrideWith((ref) async => bins),
      mappingProvider.overrideWith((ref) async => mappingOverride ?? mapping),
      ...overrides,
    ],
    child: MaterialApp(theme: buildAppTheme(), home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    bins = await BinsRepository().loadBins();
    mapping = await MappingLoader().loadMapping();
  });

  test('nearestDongTo — 철산역 최근접 거점(전 타입)의 법정동 = 철산동', () {
    expect(nearestDongTo(bins), '철산동');
  });

  group('GapScreen · styrofoam (tooFar) — 목업 ⑤ 요소', () {
    testWidgets('크래시 없이 렌더: 나침반·대제목·일직동·도보 96분·CTA 2종',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester
          .pumpWidget(_wrap(const GapScreen(categoryId: 'styrofoam')));
      await tester.pumpAndSettle();

      final label = mapping.byId('styrofoam')!.label;
      // 앱바: '{라벨} · {내 동네}'.
      expect(find.text('$label · 철산동'), findsOneWidget);
      // 나침반 원형 아이콘.
      expect(find.text('🧭'), findsOneWidget);
      // 대제목.
      expect(find.text('근처에 $label\n받는 곳이 없어요'), findsOneWidget);
      // 가장 가까운 곳 = 일직동 (실계산).
      expect(
        find.textContaining('가장 가까운 곳은', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('일직동', findRichText: true), findsWidgets);
      expect(find.text('도보 96분 · 6.4km'), findsOneWidget);
      // CTA 2종.
      expect(find.text('일직동 위치 보기'), findsOneWidget);
      expect(find.text('이 사각지대를 광명시에 알리기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('[알리기] 탭 → logCivicReport(철산동, 매핑 플래그) + 확인 배너',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final logger = InMemoryEventLogger();
      await tester.pumpWidget(_wrap(
        const GapScreen(categoryId: 'styrofoam'),
        overrides: [eventLoggerProvider.overrideWithValue(logger)],
      ));
      await tester.pumpAndSettle();

      // 탭 전 — 배너 없음.
      expect(
        find.textContaining('알린 내용은 시 정책 데이터로 반영됩니다'),
        findsNothing,
      );

      await tester.ensureVisible(find.text('이 사각지대를 광명시에 알리기'));
      await tester.tap(find.text('이 사각지대를 광명시에 알리기'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('알린 내용은 시 정책 데이터로 반영됩니다'),
        findsOneWidget,
      );
      expect(logger.civicReports, hasLength(1));
      expect(logger.civicReports.single.dong, '철산동');
      // 품목은 매핑 단일 소스에서 온 CSV 플래그 값.
      expect(logger.civicReports.single.item,
          mapping.byId('styrofoam')!.csvFlags.first);

      // 재탭 방지 — 버튼 비활성으로 이벤트 중복 적재 없음.
      await tester.tap(find.text('이 사각지대를 광명시에 알리기'),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(logger.civicReports, hasLength(1));
    });
  });

  group('GapScreen · cityAbsent — 시 전체 부재 변형 카피', () {
    testWidgets('거점 0곳 카테고리 → "광명시 전체에 아직 없어요" + 위치 보기 CTA 없음',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // 식용유 = CSV Y 0행(죽은 매핑) — 시 전체 부재를 실데이터로 재현.
      const phantom = RecycleMapping(
        categories: [
          RecycleCategory(id: 'phantom', label: '가상품목', csvFlags: ['식용유']),
        ],
        confidenceThreshold: 0.7,
      );
      await tester.pumpWidget(_wrap(
        const GapScreen(categoryId: 'phantom'),
        mappingOverride: phantom,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('광명시 전체에 아직 없어요'), findsOneWidget);
      expect(find.textContaining('위치 보기'), findsNothing);
      expect(find.text('이 사각지대를 광명시에 알리기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('GapScreen · 알 수 없는 카테고리 graceful', () {
    testWidgets('mapping에 없는 id → 안내 문구, 크래시 금지', (tester) async {
      await tester
          .pumpWidget(_wrap(const GapScreen(categoryId: 'no-such-category')));
      await tester.pumpAndSettle();

      expect(find.textContaining('알 수 없는 품목'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
