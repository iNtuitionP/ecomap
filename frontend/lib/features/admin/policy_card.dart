import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';

/// 우선순위(1-base 순위) → 강조색. [PriorityChip]과 동일 규칙:
/// 1 빨강 / 2 주황 / 그 외 노랑 — 심각도 바를 칩과 같은 색으로 칠한다(목업 ⑥).
Color priorityColor(int priority) => switch (priority) {
      1 => AppColors.severityRed,
      2 => AppColors.severityOrange,
      _ => AppColors.severityYellow,
    };

/// evidence 요약 부제 생성 — '일직동 외 6개 법정동 거점 0' 식 (SPEC T8).
///
/// 문구 하드코딩 금지: covered_dongs·bin_counts(policy_cards.json 산출물)에서
/// 거점 보유 동과 거점 0 법정동 수를 세어 조립한다.
String evidenceSummary(PolicyCard card) {
  final binCounts =
      card.evidence['bin_counts'] as Map<String, dynamic>? ?? const {};
  final zeroCount =
      binCounts.values.where((count) => (count as num? ?? 0) == 0).length;
  final covered = (card.evidence['covered_dongs'] as List<dynamic>? ?? const [])
      .cast<String>();
  if (covered.isEmpty) {
    return '전체 $zeroCount개 법정동 거점 0';
  }
  final head = covered.length == 1
      ? covered.first
      : '${covered.first} 등 ${covered.length}개 동';
  return '$head 외 $zeroCount개 법정동 거점 0';
}

/// 공백분석 정책카드 1건 뷰 — 목업 demo-flow ⑥ · new-screens ①.
///
/// 우선순위 칩 → 제목 '{동} {품목} 수거 사각지대' → evidence 요약 부제 →
/// '→ 행정 액션' 그린 강조줄 → 추정 효과 → severity_score 프로그레스 바.
/// 전 필드가 policy_cards.json 원문에서 온다.
class PolicyCardView extends StatelessWidget {
  const PolicyCardView({
    super.key,
    required this.card,
    required this.priority,
  });

  /// 정책카드 데이터 (T3 동결 산출물의 1건).
  final PolicyCard card;

  /// severity_score 내림차순 순위 (1-base).
  final int priority;

  @override
  Widget build(BuildContext context) {
    final Color color = priorityColor(priority);

    // action 원문은 '핵심 제안 — 근거 상세' 구조. 앞부분을 그린 강조줄로,
    // 뒷부분(현황 상세)은 보조 캡션으로 나눠 보여 준다. 대시가 없으면 전체가 강조줄.
    final List<String> actionParts = card.action.split(' — ');
    final String actionHead = actionParts.first.trim();
    final String actionDetail =
        actionParts.length > 1 ? actionParts.sublist(1).join(' — ').trim() : '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PriorityChip(priority: priority),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${card.dong} ${card.item} 수거 사각지대',
            style: AppTextStyles.section.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(evidenceSummary(card), style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.md),
          Text(
            '→ $actionHead',
            style: AppTextStyles.body.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionDetail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(actionDetail, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            card.estEffect,
            style: AppTextStyles.caption.copyWith(color: AppColors.textBody),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '심각도 점수',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ),
              Text(
                '${card.severityScore}',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              // 값은 데이터 그대로 — 표시만 0~1로 클램프(과장 금지).
              value: card.severityScore.clamp(0.0, 1.0),
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.divider,
            ),
          ),
        ],
      ),
    );
  }
}
