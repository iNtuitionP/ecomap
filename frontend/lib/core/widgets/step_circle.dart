import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 분리배출 가이드 단계 번호 원 (목업 ③).
class StepCircle extends StatelessWidget {
  const StepCircle({super.key, required this.number, this.size = 28});

  /// 1부터 시작하는 단계 번호.
  final int number;

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
