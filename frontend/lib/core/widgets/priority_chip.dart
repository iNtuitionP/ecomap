import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 정책카드 우선순위 칩 — 1 빨강 / 2 주황 / 3 노랑 (목업 ⑥).
class PriorityChip extends StatelessWidget {
  const PriorityChip({super.key, required this.priority});

  /// 우선순위 (1–3). 범위 밖 값은 3(노랑)으로 처리.
  final int priority;

  Color get _color => switch (priority) {
        1 => AppColors.severityRed,
        2 => AppColors.severityOrange,
        _ => AppColors.severityYellow,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '우선순위 $priority',
        style: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.3,
        ),
      ),
    );
  }
}
