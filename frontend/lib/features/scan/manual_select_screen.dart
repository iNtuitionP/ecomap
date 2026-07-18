import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../services/recognition/recognition_providers.dart';
import '../../shared/mapping_loader.dart';
import 'widgets/captured_preview.dart';

/// 품목 직접 선택 화면 — 목업 신규 ③ 완전 구현.
///
/// 라우트: `/select` (직접 진입) · `/select?conf=0.41` (저신뢰 fallback).
/// conf가 있으면 미리보기 + '잘 모르겠어요 · NN%' 주황 칩으로 진입 사유를
/// 보여주고, 8카테고리 그리드에서 고르면 `/result/:id?manual=1`로 이동한다.
class ManualSelectScreen extends ConsumerWidget {
  const ManualSelectScreen({super.key, this.confidence});

  /// 저신뢰 인식의 confidence (쿼리 `conf`). 직접 진입이면 null.
  final double? confidence;

  /// 카테고리 id → 이모지 아이콘 (그리드 셀). 라벨은 mapping_loader에서.
  static const Map<String, String> categoryEmoji = {
    'pet': '🧴',
    'can': '🥫',
    'paper': '📄',
    'vinyl': '🛍️',
    'glass': '🍾',
    'styrofoam': '📦',
    'papercup': '🥛',
    'etc': '❓',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mappingAsync = ref.watch(mappingProvider);
    final fromLowConfidence = confidence != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '다시 촬영',
          onPressed: () => context.go('/scan'),
        ),
        title: Text(fromLowConfidence ? '촬영 결과' : '품목 직접 선택'),
      ),
      body: mappingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text('카테고리를 불러오지 못했어요', style: AppTextStyles.caption),
        ),
        data: (mapping) => _SelectBody(
          mapping: mapping,
          confidence: confidence,
        ),
      ),
    );
  }
}

class _SelectBody extends ConsumerWidget {
  const _SelectBody({required this.mapping, required this.confidence});

  final RecycleMapping mapping;
  final double? confidence;

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
        if (confidence != null) ...[
          CapturedPreview(bytes: bytes, height: 170),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                CategoryBadge(
                  label: '잘 모르겠어요',
                  confidencePercent: (confidence! * 100).round(),
                  lowConfidence: true,
                ),
                const SizedBox(width: AppSpacing.md),
                Text('신뢰도 낮음', style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        const SectionTitle(text: '직접 골라주세요'),
        const SizedBox(height: AppSpacing.xs),
        Text('이 품목이 무엇에 가까운가요?', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: AppSpacing.sm + 2,
          crossAxisSpacing: AppSpacing.sm + 2,
          childAspectRatio: 0.76,
          children: [
            for (final category in mapping.categories)
              _CategoryCell(category: category),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _AutoRecognitionHint(mapping: mapping),
      ],
    );
  }
}

/// 8카테고리 그리드 셀 — 이모지 + 라벨(mapping_loader), 탭 → 결과 화면.
class _CategoryCell extends StatelessWidget {
  const _CategoryCell({required this.category});

  final RecycleCategory category;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: ValueKey('category-cell-${category.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      onTap: () => context.go('/result/${category.id}?manual=1'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            ManualSelectScreen.categoryEmoji[category.id] ?? '❓',
            style: const TextStyle(fontSize: 26, height: 1.2),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            category.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11.5,
              color: AppColors.textBody,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// 하단 안내 — '참고 · 신뢰도 높으면 자동 인식' + 예시 그린 칩 (목업 ③).
class _AutoRecognitionHint extends StatelessWidget {
  const _AutoRecognitionHint({required this.mapping});

  final RecycleMapping mapping;

  @override
  Widget build(BuildContext context) {
    // 예시 칩 라벨도 단일 소스(mapping)에서 — 데모 각본 카테고리(pet).
    final demoLabel =
        (mapping.byId('pet') ?? mapping.categories.first).label;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Text('참고 · 신뢰도 높으면 자동 인식', style: AppTextStyles.caption),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$demoLabel · 96%',
            style: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
