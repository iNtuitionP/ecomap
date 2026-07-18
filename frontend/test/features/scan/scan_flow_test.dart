// T5 · recognition-flow — 스캔 화면 conf 분기 위젯 테스트.
//
// 데모 3차 액션('데모 품목으로 체험하기')으로 인식을 트리거해
// (1) conf ≥ 0.7(경계 포함) → 결과 화면, (2) conf < 0.7 → 수동 선택 + 주황 칩,
// (3) 인식 예외 → 수동 선택 graceful 폴백(SPEC T5-4)을 검증한다.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecomap/core/router.dart';
import 'package:ecomap/core/theme/app_theme.dart';
import 'package:ecomap/data/providers.dart';
import 'package:ecomap/services/recognition/recognition_providers.dart';
import 'package:ecomap/services/recognition/recognition_service.dart';

import 'scan_test_support.dart';

/// 고정 결과 스텁 — 딜레이 없이 즉시 반환.
class StubRecognitionService implements RecognitionService {
  StubRecognitionService(this.result);

  final RecognitionResult result;

  @override
  Future<RecognitionResult> recognize({Uint8List? imageBytes}) async => result;
}

/// 항상 실패하는 스텁 — API 타임아웃/에러 목킹.
class ThrowingRecognitionService implements RecognitionService {
  @override
  Future<RecognitionResult> recognize({Uint8List? imageBytes}) async {
    throw const RecognitionException('mocked API failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 결과 화면의 이벤트 로깅(T7 install_id)이 SharedPreferences를 쓴다.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final mapping = loadMappingFromDisk();
  final firstCategory = mapping.categories.first;

  /// ListView 하단(뷰포트 밖)의 위젯을 스크롤로 드러낸다.
  Future<void> revealInList(WidgetTester tester, Finder finder) async {
    await tester.dragUntilVisible(
      finder,
      find.byType(ListView).first,
      const Offset(0, -140),
    );
    await tester.pumpAndSettle();
  }

  Future<GoRouter> pumpScan(
    WidgetTester tester, {
    required RecognitionService service,
  }) async {
    final container = ProviderContainer(
      overrides: [
        // FakeAsync에서 rootBundle 로드가 멈추는 문제 회피 — 동기 파일 번들.
        assetBundleProvider.overrideWithValue(SyncFileAssetBundle()),
        recognitionServiceProvider.overrideWith((ref) async => service),
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
    router.go('/scan');
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('스캔 화면: 뷰파인더 카피·CTA·데모 액션이 렌더된다', (tester) async {
    await pumpScan(
      tester,
      service: StubRecognitionService(
        RecognitionResult(categoryId: firstCategory.id, confidence: 0.96),
      ),
    );

    expect(find.text('품목을 화면에 담아주세요'), findsOneWidget);
    expect(find.text('바코드 없이 물건 그대로 찍으면 됩니다'), findsOneWidget);
    expect(find.text('촬영하기'), findsOneWidget);
    expect(find.text('앨범에서 선택'), findsOneWidget);
    // API 키 없는 테스트 환경 = 데모 모드 → 3차 액션 노출.
    expect(find.text('데모 품목으로 체험하기 ›'), findsOneWidget);
  });

  testWidgets('conf 0.7(경계) → 자동 인식: /result 로 이동해 배지·가이드 요약 표시',
      (tester) async {
    await pumpScan(
      tester,
      service: StubRecognitionService(
        RecognitionResult(categoryId: firstCategory.id, confidence: 0.7),
      ),
    );

    await tester.tap(find.text('데모 품목으로 체험하기 ›'));
    await tester.pumpAndSettle();

    // 결과 화면 마커: 제목 + 카테고리 배지(70%) + 가이드 요약.
    expect(find.text('인식 결과'), findsOneWidget);
    expect(find.text('✓ ${firstCategory.label} · 70%'), findsOneWidget);
    expect(find.text('자동 인식'), findsOneWidget);
    expect(find.text('이렇게 버리세요'), findsOneWidget);

    // 하단 신뢰 카피는 스크롤로 드러난다.
    final trustCopy = find.text('제품명·브랜드는 안 봐요 — 품목만 정확히');
    await revealInList(tester, trustCopy);
    expect(trustCopy, findsOneWidget);
  });

  testWidgets('conf 0.69(< 0.7) → 저신뢰: /select 로 이동해 주황 칩 표시', (tester) async {
    await pumpScan(
      tester,
      service: StubRecognitionService(
        RecognitionResult(categoryId: firstCategory.id, confidence: 0.69),
      ),
    );

    await tester.tap(find.text('데모 품목으로 체험하기 ›'));
    await tester.pumpAndSettle();

    // 수동 선택 화면 + 진입 사유(저신뢰) 칩.
    expect(find.text('직접 골라주세요'), findsOneWidget);
    expect(find.text('잘 모르겠어요 · 69%'), findsOneWidget);
    expect(find.text('신뢰도 낮음'), findsOneWidget);
  });

  testWidgets('인식 예외(API 에러 목킹) → 크래시 없이 /select 폴백', (tester) async {
    await pumpScan(tester, service: ThrowingRecognitionService());

    await tester.tap(find.text('데모 품목으로 체험하기 ›'));
    await tester.pumpAndSettle();

    // graceful: 수동 선택 화면(직접 진입 모드 — 칩 없음).
    expect(find.text('직접 골라주세요'), findsOneWidget);
    expect(find.text('품목 직접 선택'), findsOneWidget);
    expect(find.textContaining('잘 모르겠어요'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
