import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'policy_card.dart';

/// 어드민 공백 분석 화면 — 데모 클라이맥스 (목업 demo-flow ⑥ · new-screens ①).
///
/// 라우트: `/admin`. 커버리지 스트립(법정동 × 품목 미니 히트맵) →
/// severity_score 상위부터 정책카드 리스트 → 산출 근거 캡션.
/// 숫자·문구는 전부 policy_cards.json(T3 동결 산출물)에서 온다 — 하드코딩 금지.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(policyCardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('분리배출 공백 분석'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.screenEdge),
            child: Center(
              child: Text('광명시 자원순환과', style: AppTextStyles.caption),
            ),
          ),
        ],
      ),
      body: doc.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenEdge),
            child: Text(
              '정책카드 데이터를 불러오지 못했어요.\n앱을 다시 실행해 주세요.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (doc) => _AdminBody(doc: doc),
      ),
    );
  }
}

/// 본문 — 커버리지 스트립 + 정책카드 전건(내림차순) + 산출 근거.
class _AdminBody extends StatelessWidget {
  const _AdminBody({required this.doc});

  final PolicyCardsDocument doc;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenEdge,
          AppSpacing.sm,
          AppSpacing.screenEdge,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverageStrip(doc: doc),
            const SizedBox(height: AppSpacing.xl),
            SectionTitle(
              text: '정책 제안 카드',
              trailing: Text(
                '우선순위순 · ${doc.cards.length}건',
                style: AppTextStyles.caption,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < doc.cards.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              PolicyCardView(card: doc.cards[i], priority: i + 1),
            ],
            const SizedBox(height: AppSpacing.xl),
            _SourceFootnote(doc: doc),
          ],
        ),
      ),
    );
  }
}

/// 상단 커버리지 스트립 — 법정동 × 품목 미니 히트맵 (과장 없는 실데이터 그리드).
///
/// 셀 색: 거점 있음(라이트 그린) / 공백(카드 severity 색) / 시 전체 부재(회색).
/// 공백 셀은 정책카드 23건과 1:1 — gap_cell_count 그대로다.
class _CoverageStrip extends StatelessWidget {
  const _CoverageStrip({required this.doc});

  final PolicyCardsDocument doc;

  static Color _severityColor(String severity) => switch (severity) {
        'high' => AppColors.severityRed,
        'medium' => AppColors.severityOrange,
        _ => AppColors.severityYellow,
      };

  @override
  Widget build(BuildContext context) {
    // (법정동, 품목) → 공백 카드 룩업. 카드가 없으면 거점 보유 셀.
    final gapByCell = <String, PolicyCard>{
      for (final card in doc.cards) '${card.dong}|${card.item}': card,
    };

    Color cellColor(String dong, String item) {
      if (doc.globalAbsentItems.contains(item)) return AppColors.divider;
      final gap = gapByCell['$dong|$item'];
      if (gap == null) return AppColors.accent;
      return _severityColor(gap.severity);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            text: '수거 거점 커버리지',
            trailing: Text(
              '공백 ${doc.gapCellCount}칸',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.severityRed,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgSage,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Column(
              children: [
                for (final dong in doc.dongs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(
                            dong,
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                          ),
                        ),
                        for (final item in doc.items)
                          Expanded(
                            child: Container(
                              height: 12,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 1.5),
                              decoration: BoxDecoration(
                                color: cellColor(dong, item),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              const _LegendDot(color: AppColors.accent, label: '거점 있음'),
              const _LegendDot(color: AppColors.severityRed, label: '공백·심각'),
              const _LegendDot(color: AppColors.severityOrange, label: '공백·보통'),
              const _LegendDot(color: AppColors.severityYellow, label: '공백·낮음'),
              if (doc.globalAbsentItems.isNotEmpty)
                const _LegendDot(color: AppColors.divider, label: '시 전체 부재'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '법정동 ${doc.dongs.length} × 품목 ${doc.items.length}'
            ' = ${doc.dongs.length * doc.items.length}칸 분석',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textBody,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // SPEC T8-2 정직 라벨링 — 목업 ⑥ 카피 원문 유지.
          Text('시민 데이터 · 트래픽 0에서도 산출', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// 범례 1항목 — 색 점 + 라벨.
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

/// 하단 산출 근거 캡션 — policy_cards.json 메타(unit·source·severity_criteria) 소비.
class _SourceFootnote extends StatelessWidget {
  const _SourceFootnote({required this.doc});

  final PolicyCardsDocument doc;

  @override
  Widget build(BuildContext context) {
    // unit 코드값 → 화면 표기 (beopjeong = 법정동).
    final String unitLabel = doc.unit == 'beopjeong' ? '법정동' : doc.unit;
    final String binRows = '${doc.source['bin_rows'] ?? '-'}';
    final String binsPath = '${doc.source['bins'] ?? '-'}';
    final String populationAsOf = '${doc.source['population_as_of'] ?? '-'}';
    final String formula = '${doc.severityCriteria['formula'] ?? '-'}';

    final TextStyle line = AppTextStyles.caption.copyWith(fontSize: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '산출 근거',
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('산출 단위: $unitLabel · 수거 거점 데이터 $binRows행 ($binsPath)', style: line),
        const SizedBox(height: AppSpacing.xs),
        Text('심각도 산식: $formula', style: line),
        const SizedBox(height: AppSpacing.xs),
        Text('추정 효과: 주민등록 인구 $populationAsOf 기준', style: line),
      ],
    );
  }
}
