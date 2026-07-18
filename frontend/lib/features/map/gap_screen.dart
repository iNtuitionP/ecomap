/// 사각지대(빈 최근접) 화면 — 목업 ⑤ · SPEC T6-2 [CRITICAL 엣지].
///
/// 근처(1.5km)에 해당 품목 Y 거점이 없을 때 빈 지도 대신 이 화면을 보여준다:
/// - tooFar   : "근처에 {라벨} 받는 곳이 없어요" + 가장 가까운 법정동·도보 실계산
///              + [{동} 위치 보기](해당 거점 좌표로 /map 포커스 이동)
/// - cityAbsent: "광명시 전체에 아직 없어요" 변형 카피
/// - 공통     : [이 사각지대를 광명시에 알리기] → EventLogger.logCivicReport
///              + 확인 배너 (시민 제보 → 시 정책 데이터 반영)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/nearest_service.dart';
import '../../data/providers.dart';
import '../../shared/mapping_loader.dart';
import 'map_screen.dart' show formatDistance;

/// 데모 기준 위치(철산역)에서 가장 가까운 거점(전 타입)의 법정동 — "내 동네" 표기용.
///
/// 역지오코딩 플러그인 없이 T1 산출 법정동 데이터만으로 판별한다.
@visibleForTesting
String nearestDongTo(List<BinRecord> bins) {
  if (bins.isEmpty) return '';
  BinRecord? best;
  var bestD = double.infinity;
  for (final bin in bins) {
    final d = haversineMeters(
        demoLocation.latitude, demoLocation.longitude, bin.lat, bin.lng);
    if (d < bestD) {
      bestD = d;
      best = bin;
    }
  }
  return best?.beopjeong ?? '';
}

/// 공백(빈 최근접) 상태 화면.
class GapScreen extends ConsumerStatefulWidget {
  const GapScreen({super.key, required this.categoryId});

  /// mapping.json 카테고리 id (예: styrofoam).
  final String categoryId;

  @override
  ConsumerState<GapScreen> createState() => _GapScreenState();
}

class _GapScreenState extends ConsumerState<GapScreen> {
  bool _reported = false;

  Future<void> _report(RecycleCategory category, String dong) async {
    // 품목명은 매핑 단일 소스의 CSV 플래그 값 그대로 (T4 — 리터럴 금지).
    await ref
        .read(eventLoggerProvider)
        .logCivicReport(dong: dong, item: category.csvFlags.first);
    if (mounted) setState(() => _reported = true);
  }

  @override
  Widget build(BuildContext context) {
    final binsAsync = ref.watch(binsProvider);
    final mappingAsync = ref.watch(mappingProvider);

    if (binsAsync.hasError || mappingAsync.hasError) {
      return _shell(
        title: '수거 공백 안내',
        child: Text(
          '데이터를 불러오지 못했어요.\n잠시 후 다시 시도해 주세요',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      );
    }
    final bins = binsAsync.value;
    final mapping = mappingAsync.value;
    if (bins == null || mapping == null) {
      return _shell(
        title: '수거 공백 안내',
        child: const CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final category = mapping.byId(widget.categoryId);
    if (category == null) {
      // 잘못된 딥링크 등 — graceful 안내 (크래시 금지).
      return _shell(
        title: '수거 공백 안내',
        child: Text(
          '알 수 없는 품목이에요.\n지도에서 전체 수거함을 확인해 주세요',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      );
    }

    final myDong = nearestDongTo(bins);
    final result = NearestService(mapping: mapping)
        .findNearest(categoryId: category.id, bins: bins);

    return _shell(
      title: myDong.isEmpty ? category.label : '${category.label} · $myDong',
      child: switch (result) {
        TooFarGap gap => _tooFarBody(category, gap, myDong),
        CityAbsentGap() => _cityAbsentBody(category, myDong),
        // 방어: 근처 거점이 있으면 공백 화면 대신 지도 안내.
        NearbyResult() => _nearbyFallbackBody(category),
      },
    );
  }

  /// 공통 스캐폴드 — 중앙 정렬 + 스크롤 안전.
  Widget _shell({required String title, required Widget child}) {
    return Scaffold(
      appBar: AppBar(leading: const _BackButton(), title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenEdge),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tooFarBody(RecycleCategory category, TooFarGap gap, String myDong) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CompassBadge(),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          '근처에 ${category.label}\n받는 곳이 없어요',
          textAlign: TextAlign.center,
          style: AppTextStyles.title.copyWith(fontSize: 24, height: 1.35),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text.rich(
          TextSpan(
            text: '가장 가까운 곳은 ',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            children: [
              TextSpan(
                text: gap.nearestDong,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textBody,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '도보 ${gap.walkMinutes}분 · ${formatDistance(gap.distanceM)}',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: '${gap.nearestDong} 위치 보기',
          onPressed: () => context.go(
            '/map/${category.id}'
            '?lat=${gap.nearestBin.lat}&lng=${gap.nearestBin.lng}',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ..._civicSection(category, myDong),
      ],
    );
  }

  Widget _cityAbsentBody(RecycleCategory category, String myDong) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CompassBadge(),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          '${category.label} 받는 곳이\n광명시 전체에 아직 없어요',
          textAlign: TextAlign.center,
          style: AppTextStyles.title.copyWith(fontSize: 24, height: 1.35),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '수거 인프라가 아직 없는 품목이에요.\n알려주시면 확충 검토에 반영됩니다',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 28),
        ..._civicSection(category, myDong),
      ],
    );
  }

  /// 방어 분기 — 공백이 아닌데 이 화면에 들어온 경우.
  Widget _nearbyFallbackBody(RecycleCategory category) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CompassBadge(),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          '가까운 곳에 ${category.label}\n받는 곳이 있어요',
          textAlign: TextAlign.center,
          style: AppTextStyles.title.copyWith(fontSize: 24, height: 1.35),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: '지도에서 보기',
          onPressed: () => context.go('/map/${category.id}'),
        ),
      ],
    );
  }

  /// 시민 제보 CTA + 확인 배너 (civic 액션 — 시 정책 데이터의 입력이 된다).
  List<Widget> _civicSection(RecycleCategory category, String myDong) {
    return [
      OutlinedActionButton(
        label: '이 사각지대를 광명시에 알리기',
        onPressed: _reported ? null : () => _report(category, myDong),
      ),
      if (_reported) ...[
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  '알린 내용은 시 정책 데이터로 반영됩니다',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}

/// 나침반 원형 아이콘 — 세이지/라이트그린 원 배경 (목업 ⑤).
class _CompassBadge extends StatelessWidget {
  const _CompassBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent.withValues(alpha: 0.3),
        ),
        alignment: Alignment.center,
        child: const Text('🧭', style: TextStyle(fontSize: 42)),
      ),
    );
  }
}

/// 뒤로가기 — pop 불가(리다이렉트 진입) 시 전체 지도로.
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '뒤로',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/map');
        }
      },
    );
  }
}
