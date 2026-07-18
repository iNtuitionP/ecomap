import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 인식 결과 카테고리 칩.
///
/// 고신뢰: 그린 칩 `✓ 무색 페트병 · 96%` (목업 ②).
/// 저신뢰([lowConfidence] true): 주황 칩 `잘 모르겠어요 · 41%` (목업 신규 ③).
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.label,
    required this.confidencePercent,
    this.lowConfidence = false,
  });

  /// 카테고리 라벨 (예: '무색 페트병'). 문자열은 mapping_loader 에서 가져올 것.
  final String label;

  /// 신뢰도 퍼센트 (0–100 정수).
  final int confidencePercent;

  /// true 면 저신뢰(주황) 스타일.
  final bool lowConfidence;

  @override
  Widget build(BuildContext context) {
    final Color background =
        lowConfidence ? AppColors.severityOrange : AppColors.primary;
    final String text = lowConfidence
        ? '$label · $confidencePercent%'
        : '✓ $label · $confidencePercent%';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    );
  }
}
