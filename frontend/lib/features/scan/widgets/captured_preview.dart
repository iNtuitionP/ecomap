import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 촬영 이미지 미리보기 — 결과·수동선택 화면 공용 (목업 ②·신규 ③).
///
/// [bytes]가 있으면 사진, 없으면 빗금 플레이스홀더('촬영한 품목').
class CapturedPreview extends StatelessWidget {
  const CapturedPreview({super.key, this.bytes, this.height = 200});

  final Uint8List? bytes;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Widget child = bytes != null
        ? Image.memory(
            bytes!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
          )
        : CustomPaint(
            painter: _HatchPainter(),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.photo_camera_outlined,
                    size: 26,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('촬영한 품목', style: AppTextStyles.caption),
                ],
              ),
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        height: height,
        width: double.infinity,
        color: AppColors.divider,
        child: child,
      ),
    );
  }
}

/// 45° 빗금 배경 (목업 신규 ③ 플레이스홀더 질감).
class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.12)
      ..strokeWidth = 7;
    const gap = 18.0;
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPainter oldDelegate) => false;
}
