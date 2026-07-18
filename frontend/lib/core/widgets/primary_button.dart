import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 풀폭 그린 CTA 버튼 — 높이 54, 라운드 14 (목업 정본 스타일).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  /// 버튼 라벨 (한국어 존댓말 카피).
  final String label;

  final VoidCallback? onPressed;

  /// 라벨 앞 아이콘 (선택).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Widget button = icon == null
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            label: Text(label),
          );
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.ctaHeight,
      child: button,
    );
  }
}
