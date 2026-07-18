import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 흰색 카드 — 라운드 20, 은은한 그림자. [onTap]이 있으면 잉크 리플.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color = AppColors.card,
  });

  final Widget child;

  final EdgeInsetsGeometry padding;

  /// 탭 콜백 (선택) — 카드 전체가 탭 타깃이 된다.
  final VoidCallback? onTap;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141C2B21),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
