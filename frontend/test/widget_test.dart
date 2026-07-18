// 홈 화면 렌더 스모크 테스트 — CTA 존재 + 라우팅.
//
// 앱 셸(하단 네비 4탭) 위에 홈이 뜨고, 주요 CTA가 각 실제 화면으로
// 이동하는지 확인한다(라우팅 계약: 경로·타이틀).
//
// 지도 탭은 실제 MapScreen을 띄우므로 map_screen_test와 같은 이유로
// 타일 레이어(네트워크)와 대용량 에셋 로드(FakeAsync 존에서 미완료)를
// setUpAll 선로딩 + 프로바이더 오버라이드로 대체한다.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/data/bins_repository.dart';
import 'package:ecomap/data/models.dart';
import 'package:ecomap/data/policy_repository.dart';
import 'package:ecomap/data/providers.dart';
import 'package:ecomap/features/map/map_screen.dart';
import 'package:ecomap/main.dart';
import 'package:ecomap/shared/mapping_loader.dart';

// 위젯 테스트 본문은 FakeAsync 존이라 대용량 에셋 로드(isolate 디코드)가
// 완료되지 않는다 — setUpAll(실 async)에서 미리 로드해 프로바이더를 덮는다.
late List<BinRecord> bins;
late RecycleMapping mapping;
late PolicyCardsDocument policyDoc;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    bins = await BinsRepository().loadBins();
    mapping = await MappingLoader().loadMapping();
    policyDoc = await PolicyRepository().load();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapTileLayerProvider.overrideWithValue(const SizedBox.shrink()),
          binsProvider.overrideWith((ref) async => bins),
          mappingProvider.overrideWith((ref) async => mapping),
          policyCardsProvider.overrideWith((ref) async => policyDoc),
        ],
        child: const EcoMapApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('홈: 헤더·히어로·CTA·진입 카드가 렌더된다', (tester) async {
    await pumpApp(tester);

    // 브랜드 헤더
    expect(find.text('에코지도 찌릿'), findsOneWidget);

    // 히어로 카드
    expect(find.text('스마트 분리수거'), findsOneWidget);

    // 핵심 CTA 2종
    expect(find.text('촬영으로 분리배출 확인'), findsOneWidget);
    expect(find.text('직접 선택하기'), findsOneWidget);

    // 수거함 지도 진입 카드 (실데이터 274곳)
    expect(find.text('내 주변 수거함 274곳'), findsOneWidget);
    expect(find.text('광명시 자원순환과 실데이터'), findsOneWidget);

    // 어드민(공백 분석) 진입 카드
    expect(find.text('분리배출 공백 분석'), findsOneWidget);
  });

  testWidgets('하단 네비: 홈·스캔·지도·공백분석 4탭이 보인다', (tester) async {
    await pumpApp(tester);

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('스캔'), findsOneWidget);
    expect(find.text('지도'), findsOneWidget);
    expect(find.text('공백분석'), findsOneWidget);
  });

  testWidgets('홈: [촬영으로 분리배출 확인] → /scan 이동', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('촬영으로 분리배출 확인'));
    await tester.pumpAndSettle();

    expect(find.text('품목 촬영'), findsOneWidget);
  });

  testWidgets('홈: [직접 선택하기] → /select 이동', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('직접 선택하기'));
    await tester.pumpAndSettle();

    expect(find.text('품목 직접 선택'), findsOneWidget);
  });

  testWidgets('홈: 수거함 카드 → /map 이동 (실제 지도 화면 타이틀)', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('내 주변 수거함 274곳'));
    await tester.pumpAndSettle();

    // 실제 MapScreen 앱바 타이틀 (목업 ④ 정본 — map_screen_test와 동일 계약).
    expect(find.text('내 주변 수거함'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('홈: 공백 분석 카드 → /admin 이동 (자원순환과 라벨 노출)', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('분리배출 공백 분석'));
    await tester.pumpAndSettle();

    // 어드민 앱바 우측 '광명시 자원순환과' 라벨 (목업 ⑥)
    expect(find.text('광명시 자원순환과'), findsOneWidget);
  });
}
