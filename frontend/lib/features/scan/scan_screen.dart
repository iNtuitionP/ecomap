import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../services/recognition/recognition_providers.dart';

/// 스캔(품목 촬영) 화면 — 목업 ① 완전 구현.
///
/// 다크그린 뷰파인더 카드 + [촬영하기] CTA + '앨범에서 선택' 보조 액션.
/// 데모 모드(API 키 없음)에서는 '데모 품목으로 체험하기' 3차 액션 노출.
/// 인식 결과 conf ≥ threshold → `/result/:id`, 미만 → `/select`.
/// 예외는 전부 수동 선택으로 graceful 폴백 (SPEC T5-4).
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  /// [촬영하기] — 카메라, 웹/미지원이면 앨범 폴백.
  Future<void> _onCapture() async {
    XFile? file;
    if (kIsWeb) {
      // 웹은 카메라 스트림 대신 파일 선택으로 폴백 (SPEC T5 카메라 정책).
      file = await _pickSafe(ImageSource.gallery);
    } else {
      try {
        file = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 88,
        );
      } catch (_) {
        // 카메라 미지원/권한 거부 → 앨범 폴백 (SPEC T5-5).
        file = await _pickSafe(ImageSource.gallery);
      }
    }
    await _recognizeFile(file);
  }

  /// '앨범에서 선택' 보조 액션.
  Future<void> _onPickFromAlbum() async {
    await _recognizeFile(await _pickSafe(ImageSource.gallery));
  }

  /// '데모 품목으로 체험하기' — 사진 없이 인식 서비스 호출(데모 결과).
  Future<void> _onDemoItem() async {
    ref.read(capturedImageProvider.notifier).set(null);
    await _recognize(null);
  }

  Future<XFile?> _pickSafe(ImageSource source) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _recognizeFile(XFile? file) async {
    if (file == null) return; // 사용자가 취소 — 아무 일도 안 함.
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    ref.read(capturedImageProvider.notifier).set(bytes);
    await _recognize(bytes);
  }

  /// 인식 서비스 호출 → conf 분기 라우팅. 예외는 수동 선택으로.
  Future<void> _recognize(Uint8List? bytes) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = await ref.read(recognitionServiceProvider.future);
      final mapping = await ref.read(mappingProvider.future);
      final result = await service.recognize(imageBytes: bytes);
      if (!mounted) return;
      if (result.confidence >= mapping.confidenceThreshold) {
        context.go('/result/${result.categoryId}?conf=${result.confidence}');
      } else {
        context.go('/select?conf=${result.confidence}');
      }
    } catch (_) {
      // 타임아웃·API 오류 → 크래시 대신 직접 선택으로 안내 (SPEC T5-4).
      if (!mounted) return;
      context.go('/select');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool demoMode = ref.watch(demoModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('품목 촬영')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenEdge,
            AppSpacing.xs,
            AppSpacing.screenEdge,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              Expanded(child: _ViewfinderCard(busy: _busy)),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: '촬영하기',
                icon: Icons.photo_camera_rounded,
                onPressed: _busy ? null : _onCapture,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : _onPickFromAlbum,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('앨범에서 선택'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      textStyle: AppTextStyles.button.copyWith(fontSize: 14),
                    ),
                  ),
                  const Spacer(),
                  if (demoMode)
                    TextButton(
                      onPressed: _busy ? null : _onDemoItem,
                      style: TextButton.styleFrom(
                        textStyle: AppTextStyles.button.copyWith(fontSize: 14),
                      ),
                      child: const Text('데모 품목으로 체험하기 ›'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 다크그린 뷰파인더 카드 — 흰 라운드 프레임 + 점선 가이드 (목업 ①).
class _ViewfinderCard extends StatelessWidget {
  const _ViewfinderCard({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.scanDark,
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
      ),
      child: Column(
        children: [
          const Text(
            '품목을 화면에 담아주세요',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: busy ? const _RecognizingIndicator() : const _CaptureFrame()),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '바코드 없이 물건 그대로 찍으면 됩니다',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

/// 흰 라운드 프레임 + 안쪽 점선 가이드.
class _CaptureFrame extends StatelessWidget {
  const _CaptureFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 2.4,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: Colors.white.withValues(alpha: 0.35),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// 인식 중 로딩 인디케이터 — 뷰파인더 내부 (촬영/선택 후).
class _RecognizingIndicator extends StatelessWidget {
  const _RecognizingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '품목을 인식하고 있어요…',
          style: AppTextStyles.body.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

/// 점선 라운드 사각형 페인터 (뷰파인더 가이드).
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(20),
    );
    final path = Path()..addRRect(rrect);
    const dash = 7.0;
    const gap = 6.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
