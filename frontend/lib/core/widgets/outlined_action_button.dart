import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 풀폭 아웃라인 보조 버튼 — 높이 54, 라운드 14, 그린 보더.
class OutlinedActionButton extends StatelessWidget {
  const OutlinedActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;

  final VoidCallback? onPressed;

  /// 라벨 앞 아이콘 (선택).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Widget button = icon == null
        ? OutlinedButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton.icon(
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
