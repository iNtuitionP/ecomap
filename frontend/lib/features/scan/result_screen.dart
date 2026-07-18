import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../services/recognition/recognition_providers.dart';
import '../../shared/mapping_loader.dart';
import 'widgets/captured_preview.dart';

/// 인식 결과 화면 — 목업 ② 완전 구현.
///
/// 라우트: `/result/:categoryId?conf=0.96` (자동 인식) ·
/// `/result/:categoryId?manual=1` (수동 선택 진입).
/// 이미지 미리보기 + 카테고리 배지 + '이렇게 버리세요' 요약 카드 +
/// [가장 가까운 수거함 찾기] CTA. 진입 시 RECOG_EVENTS 1건 적재(T7 계약).
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({
    super.key,
    required this.categoryId,
    this.confidence,
    this.manual = false,
  });

  /// mapping.json 카테고리 id (예: pet).
  final String categoryId;

  /// 인식 신뢰도 0.0–1.0 (쿼리 `conf`). 수동 선택이면 null.
  final double? confidence;

  /// 수동 선택 진입 여부 (쿼리 `manual=1`).
  final bool manual;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  /// 데모 위치의 법정동 — 철산역 소재지. 이벤트 로깅용(T7 스키마 dong 필드).
  static const String _demoDong = '철산동';

  @override
  void initState() {
    super.initState();
    // 진입 1회당 인식 이벤트 1건 적재 (SPEC T7 Acceptance 2).
    Future.microtask(_logRecognition);
  }

  Future<void> _logRecognition() async {
    try {
      final mapping = await ref.read(mappingProvider.future);
      final category = mapping.byId(widget.categoryId);
      if (category == null || !mounted) return;
      final installId = await ref.read(installIdProvider.future);
      if (!mounted) return;
      await ref.read(eventLoggerProvider).logRecognition(
            category: category.id,
            csvFlag: category.csvFlags.first,
            confidence: widget.confidence ?? 0.0,
            manualFallback: widget.manual,
            lat: demoLocation.latitude,
            lng: demoLocation.longitude,
            dong: _demoDong,
            installId: installId,
            sessionId: ref.read(sessionIdProvider),
          );
    } catch (_) {
      // 로깅 실패는 화면을 깨지 않는다 (SPEC T5-4 graceful).
    }
  }

  @override
  Widget build(BuildContext context) {
    final mappingAsync = ref.watch(mappingProvider);
    final rulesAsync = ref.watch(rulesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '다시 촬영',
          onPressed: () => context.go('/scan'),
        ),
        title: const Text('인식 결과'),
      ),
      body: mappingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _GracefulError(),
        data: (mapping) {
          final category = mapping.byId(widget.categoryId);
          if (category == null) return const _GracefulError();
          return _ResultBody(
            category: category,
            confidence: widget.confidence,
            manual: widget.manual,
            rule: rulesAsync.asData?.value[category.id],
          );
        },
      ),
    );
  }
}

/// 결과 본문 — 미리보기 / 배지 / 요약 스텝 / CTA / 신뢰 카피.
class _ResultBody extends ConsumerWidget {
  const _ResultBody({
    required this.category,
    required this.confidence,
    required this.manual,
    required this.rule,
  });

  final RecycleCategory category;
  final double? confidence;
  final bool manual;
  final DisposalRule? rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(capturedImageProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenEdge,
        AppSpacing.xs,
        AppSpacing.screenEdge,
        AppSpacing.xxl,
      ),
      children: [
        CapturedPreview(bytes: bytes),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              if (confidence != null)
                CategoryBadge(
                  label: category.label,
                  confidencePercent: (confidence! * 100).round(),
                )
              else
                _ManualBadge(label: category.label),
              const SizedBox(width: AppSpacing.md),
              Text(manual ? '직접 선택' : '자동 인식', style: AppTextStyles.caption),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(
          text: '이렇게 버리세요',
          trailing: TextButton(
            onPressed: () => context.go('/guide/${category.id}'),
            child: const Text('전체 가이드 ›'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          onTap: () => context.go('/guide/${category.id}'),
          child: rule == null
              ? Text('배출 방법을 불러오고 있어요…', style: AppTextStyles.caption)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final step in rule!.steps) _StepLine(text: step),
                    const SizedBox(height: AppSpacing.md),
                    _CautionBox(text: rule!.caution),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: '가장 가까운 수거함 찾기',
          onPressed: () => context.go('/map/${category.id}'),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            '제품명·브랜드는 안 봐요 — 품목만 정확히',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}

/// 배출 단계 1줄 — '·' 불릿 + 본문.
class _StepLine extends StatelessWidget {
  const _StepLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '·',
            style: AppTextStyles.body.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: AppTextStyles.body.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// 주의사항 박스 — 세이지 배경 팁 (목업 ③ 톤).
class _CautionBox extends StatelessWidget {
  const _CautionBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSage,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}

/// 수동 선택 배지 — 신뢰도 없이 '✓ 라벨'만 (CategoryBadge 톤 동일).
class _ManualBadge extends StatelessWidget {
  const _ManualBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '✓ $label',
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

/// 데이터 로드 실패/알 수 없는 카테고리 — 크래시·빈화면 금지 (SPEC T5-4).
class _GracefulError extends StatelessWidget {
  const _GracefulError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenEdge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.help_outline_rounded,
              size: 44,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('품목 정보를 불러오지 못했어요', style: AppTextStyles.section),
            const SizedBox(height: AppSpacing.xs),
            Text('직접 골라주시면 바로 안내해 드릴게요', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xl),
            OutlinedActionButton(
              label: '직접 골라주세요',
              onPressed: () => context.go('/select'),
            ),
          ],
        ),
      ),
    );
  }
}
