// T8 · 어드민 공백분석 화면 — 데모 클라이맥스 (SPEC T8, 목업 demo-flow ⑥ · new-screens ①).
//
// 전부 실데이터(policy_cards.json) 기준으로 검증한다:
// - 정책카드 3건 이상 렌더 (SPEC T8-1)
// - 최상위 카드 = 스티로폼 사각지대 (실데이터 severity_score 순위)
// - '시민 데이터 · 트래픽 0에서도 산출' 정직 라벨링 카피 (SPEC T8-2)
// - 프로그레스 바 값 = severity_score, 색 = 우선순위 칩 색
// - 커버리지 스트립·산출 근거 캡션이 policy_cards.json 메타를 소비

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/core/theme/app_theme.dart';
import 'package:ecomap/data/models.dart';
import 'package:ecomap/data/policy_repository.dart';
import 'package:ecomap/data/providers.dart';
import 'package:ecomap/features/admin/admin_screen.dart';
import 'package:ecomap/features/admin/policy_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PolicyCardsDocument doc;

  setUpAll(() async {
    // 실제 동기화 에셋 로드 — 화면이 소비하는 것과 동일한 데이터.
    doc = await PolicyRepository().load();
  });

  Future<void> pumpAdmin(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 실데이터 문서를 프리로드해 fake-async 안에서 결정적으로 공급.
          policyCardsProvider.overrideWith((ref) async => doc),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const AdminScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AdminScreen (실데이터 policy_cards.json)', () {
    testWidgets('앱바: 타이틀 + 광명시 자원순환과 라벨', (tester) async {
      await pumpAdmin(tester);

      expect(find.text('분리배출 공백 분석'), findsOneWidget);
      expect(find.text('광명시 자원순환과'), findsOneWidget);
    });

    testWidgets('커버리지 스트립: 트래픽 0 카피 + 법정동×품목·공백 칸 수(메타 소비)',
        (tester) async {
      await pumpAdmin(tester);

      // SPEC T8-2 정직 라벨링 카피 (목업 ⑥ 원문 그대로).
      expect(find.text('시민 데이터 · 트래픽 0에서도 산출'), findsOneWidget);

      // 숫자 하드코딩 금지 — dongs·items·gap_cell_count 메타에서 생성.
      expect(
        find.textContaining(
          '법정동 ${doc.dongs.length} × 품목 ${doc.items.length}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('공백 ${doc.gapCellCount}칸'),
        findsWidgets,
      );
    });

    testWidgets('정책카드 3건 이상 렌더 + 우선순위 1·2·3 칩 (SPEC T8-1)', (tester) async {
      await pumpAdmin(tester);

      expect(find.byType(PolicyCardView), findsAtLeastNWidgets(3));
      expect(find.text('우선순위 1'), findsOneWidget);
      expect(find.text('우선순위 2'), findsOneWidget);
      expect(find.text('우선순위 3'), findsOneWidget);
    });

    testWidgets('최상위 카드 = 스티로폼 수거 사각지대 (실데이터 순위)', (tester) async {
      await pumpAdmin(tester);

      final top = doc.cards.first;
      // 실데이터 순위 고정: severity_score 1위는 styrofoam 카테고리다.
      expect(top.categoryId, 'styrofoam');

      // 제목 '{dong} {item} 수거 사각지대' — 데이터에서 생성.
      expect(find.text('${top.dong} ${top.item} 수거 사각지대'), findsOneWidget);

      // '우선순위 1' 칩이 첫 번째 카드에 붙어 있다.
      final firstCard = find.byType(PolicyCardView).first;
      expect(
        find.descendant(of: firstCard, matching: find.text('우선순위 1')),
        findsOneWidget,
      );
    });

    testWidgets('카드 순서 = severity_score 내림차순, 카드 전건 렌더', (tester) async {
      await pumpAdmin(tester);

      final views = tester
          .widgetList<PolicyCardView>(find.byType(PolicyCardView))
          .toList();
      expect(views, hasLength(doc.cards.length));
      for (var i = 0; i < views.length; i++) {
        expect(views[i].card.severityScore, doc.cards[i].severityScore,
            reason: 'index $i 카드가 severity_score 순위와 불일치');
        expect(views[i].priority, i + 1);
      }
    });

    testWidgets('카드 본문: 부제(evidence 요약)·→ 액션 그린줄·추정 효과', (tester) async {
      await pumpAdmin(tester);

      final top = doc.cards.first;
      final firstCard = find.byType(PolicyCardView).first;

      // 부제 — evidence에서 생성: '{거점 보유 동} 외 {N}개 법정동 거점 0' 식.
      final binCounts = top.evidence['bin_counts'] as Map<String, dynamic>;
      final zeroCount =
          binCounts.values.where((v) => (v as num) == 0).length;
      final covered =
          (top.evidence['covered_dongs'] as List<dynamic>).cast<String>();
      expect(covered, hasLength(1), reason: '실데이터 전제 확인(1위 카드 보유 동 1곳)');
      expect(
        find.descendant(
          of: firstCard,
          matching:
              find.text('${covered.first} 외 $zeroCount개 법정동 거점 0'),
        ),
        findsOneWidget,
      );

      // '→ {action}' 그린 강조줄 — action 원문(대시 앞 핵심부)에서 생성.
      final actionHead = top.action.split(' — ').first.trim();
      final actionLine = tester.widget<Text>(
        find.descendant(
          of: firstCard,
          matching: find.text('→ $actionHead'),
        ),
      );
      expect(actionLine.style?.color, AppColors.primary);

      // est_effect 원문 그대로.
      expect(
        find.descendant(of: firstCard, matching: find.text(top.estEffect)),
        findsOneWidget,
      );
    });

    testWidgets('프로그레스 바: 값 = severity_score, 색 = 칩 색', (tester) async {
      await pumpAdmin(tester);

      final cardFinders = find.byType(PolicyCardView);
      final views =
          tester.widgetList<PolicyCardView>(cardFinders).toList();

      for (var i = 0; i < views.length; i++) {
        final bar = tester.widget<LinearProgressIndicator>(
          find.descendant(
            of: cardFinders.at(i),
            matching: find.byType(LinearProgressIndicator),
          ),
        );
        expect(bar.value, closeTo(views[i].card.severityScore, 1e-9),
            reason: 'index $i 바 값이 severity_score와 다름');
        expect(bar.color, priorityColor(i + 1),
            reason: 'index $i 바 색이 우선순위 칩 색과 다름');
      }

      // 1위 카드 = 빨강 (목업 ⑥).
      final firstBar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: cardFinders.first,
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(firstBar.color, AppColors.severityRed);
      expect(firstBar.value, closeTo(doc.cards.first.severityScore, 1e-9));
    });

    testWidgets('하단 산출 근거 캡션: 단위·거점 행수·산식·주민등록 기준(메타 소비)',
        (tester) async {
      await pumpAdmin(tester);

      // unit=beopjeong → '법정동' 표기.
      expect(doc.unit, 'beopjeong');
      expect(find.textContaining('산출 단위: 법정동'), findsOneWidget);

      // source 메타에서 생성 — 숫자·문구 하드코딩 금지.
      expect(
        find.textContaining('수거 거점 데이터 ${doc.source['bin_rows']}행'),
        findsOneWidget,
      );
      expect(
        find.textContaining('주민등록 인구 ${doc.source['population_as_of']} 기준'),
        findsOneWidget,
      );

      // 심각도 산식(severity_criteria.formula) 원문 노출.
      final formula = doc.severityCriteria['formula'] as String;
      expect(find.textContaining(formula), findsOneWidget);
    });
  });
}
