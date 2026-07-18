import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../shared/mapping_loader.dart';

/// 분리배출 가이드 화면 (목업 ③) — rules.json 단계를 번호 원 + 제목 + 보조
/// 설명 + 이모지로 렌더하고, 💡 팁 배너와 하단 출처 캡션을 붙인다.
///
/// 라우트: `/guide/:categoryId` · CTA [수거함 찾기] → `/map/:categoryId`.
/// 데이터는 오직 [rulesProvider] 를 통해 읽는다 — 카테고리 하드코딩 금지.
class GuideScreen extends ConsumerWidget {
  const GuideScreen({super.key, required this.categoryId});

  /// mapping.json 카테고리 id (예: pet).
  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesProvider);

    return rulesAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('분리배출 가이드')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('분리배출 가이드')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenEdge),
            child: Text(
              '가이드 정보를 불러오지 못했어요.\n잠시 후 다시 시도해 주세요.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (rules) {
        final rule = rules[categoryId];
        if (rule == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('분리배출 가이드')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('해당 품목의 가이드를 찾지 못했어요', style: AppTextStyles.caption),
                ],
              ),
            ),
          );
        }
        return _GuideBody(categoryId: categoryId, rule: rule);
      },
    );
  }
}

/// 가이드 본문 — 단계 카드 · 팁 배너 · CTA · 출처 캡션.
class _GuideBody extends StatelessWidget {
  const _GuideBody({required this.categoryId, required this.rule});

  final String categoryId;
  final DisposalRule rule;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${rule.label} 버리는 법')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenEdge,
            AppSpacing.sm,
            AppSpacing.screenEdge,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < rule.steps.length; i++) ...[
                      if (i > 0) const Divider(),
                      _StepRow(number: i + 1, step: rule.steps[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _CautionBanner(caution: rule.caution),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: '수거함 찾기',
                onPressed: () => context.go('/map/$categoryId'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '출처 · ${rule.source}',
                style: AppTextStyles.caption.copyWith(fontSize: 11, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 단계 1행 — 번호 원 + 제목(첫 문장) + 보조 설명(나머지) + 관련 이모지.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.step});

  final int number;
  final String step;

  @override
  Widget build(BuildContext context) {
    final parts = _splitStep(step);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: StepCircle(number: number),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parts.title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (parts.detail != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(parts.detail!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              _emojiForStep(step),
              style: const TextStyle(fontSize: 20, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// 💡 caution 팁 배너 — Accent 파생 라이트 그린 배경 (색 토큰만 사용).
class _CautionBanner extends StatelessWidget {
  const _CautionBanner({required this.caution});

  final String caution;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 16, height: 1.45)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              caution,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 단계 문장을 제목(첫 문장, 끝 마침표 제거)과 보조 설명으로 나눈다.
({String title, String? detail}) _splitStep(String step) {
  final trimmed = step.trim();
  final idx = trimmed.indexOf('. ');
  if (idx == -1) {
    final title = trimmed.endsWith('.')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return (title: title, detail: null);
  }
  return (
    title: trimmed.substring(0, idx),
    detail: trimmed.substring(idx + 2),
  );
}

/// 단계 내용 키워드로 관련 이모지 선택 — 과하지 않게, 첫 매치 우선.
String _emojiForStep(String step) {
  bool has(List<String> keywords) => keywords.any(step.contains);
  if (has(const ['가스', '노즐', '깨진'])) return '⚠️';
  if (has(const ['라벨', '상표', '테이프', '스티커', '송장'])) return '🏷️';
  if (has(const ['상자', '펼치', '접어', '묶어', '부수'])) return '📦';
  if (has(const ['압착', '찌그러'])) return '🥤';
  if (has(const ['헹', '세척', '씻', '비우'])) return '💧';
  if (has(const ['전화', '방문수거', '신청'])) return '📞';
  if (has(const ['신발', '가방'])) return '👕';
  if (has(const ['보증금', '반납'])) return '💰';
  if (has(const ['종량제'])) return '🗑️';
  return '♻️';
}
