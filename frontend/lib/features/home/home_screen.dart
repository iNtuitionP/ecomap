import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';

/// 홈 화면 — 목업 rest-screens ① (스플래시/메인) 완전 구현.
///
/// 브랜드 헤더 → 그린 히어로 카드 → 촬영 CTA / 직접 선택 →
/// 수거함 지도 진입 카드 → 공백 분석(어드민) 진입 카드.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenEdge,
            AppSpacing.lg,
            AppSpacing.screenEdge,
            AppSpacing.xxl,
          ),
          children: [
            const _BrandHeader(),
            const SizedBox(height: AppSpacing.xl),
            const _HeroCard(),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: '촬영으로 분리배출 확인',
              icon: Icons.photo_camera_rounded,
              onPressed: () => context.go('/scan'),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            OutlinedActionButton(
              label: '직접 선택하기',
              onPressed: () => context.go('/select'),
            ),
            const SizedBox(height: AppSpacing.xl),
            _EntryCard(
              icon: Icons.map_rounded,
              title: '내 주변 수거함 274곳',
              subtitle: '광명시 자원순환과 실데이터',
              onTap: () => context.go('/map'),
            ),
            const SizedBox(height: AppSpacing.md),
            _EntryCard(
              icon: Icons.insights_rounded,
              title: '분리배출 공백 분석',
              subtitle: '광명시 · 수거 사각지대 정책카드',
              onTap: () => context.go('/admin'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 브랜드 로고 + 앱 이름 헤더.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/brand/logo_512.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.recycling_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Text(
          '에코지도 찌릿',
          style: AppTextStyles.title.copyWith(fontSize: 20),
        ),
      ],
    );
  }
}

/// 그린 히어로 카드 — '철산역 인근 · 스마트 분리수거' (목업 ①).
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '철산역 인근',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          const Text(
            '스마트 분리수거',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            '올바른 분리수거로\n깨끗한 우리동네 만들기',
            style: AppTextStyles.body.copyWith(
              color: const Color(0xD9FFFFFF),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Icon(Icons.recycling_rounded, size: 30, color: AppColors.accent),
              SizedBox(width: AppSpacing.md),
              Icon(Icons.eco_rounded, size: 28, color: AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }
}

/// 아이콘 + 제목 + 캡션 + 셰브론 진입 카드.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Icon(icon, size: 24, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 24,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
