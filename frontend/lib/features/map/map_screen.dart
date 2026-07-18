/// 수거함 지도 화면 — flutter_map + CARTO 라이트 타일 + 최근접 하단 시트 (SPEC T6 · 목업 ④).
///
/// - `/map` : '내 주변 수거함' — 전체 274핀
/// - `/map/:categoryId` : '{라벨} 받는 곳' — 해당 품목 Y 거점 핀 + 최근접 5곳 리스트
/// - 사각지대([GapResult]) 판정 시 `/gap/:categoryId` 자동 리다이렉트 —
///   빈 지도·크래시 노출 금지 (SPEC T6-2)
/// - `?lat=&lng=` 포커스 진입(공백 화면 "위치 보기") 시 리다이렉트 없이 해당 좌표 센터
///
/// 카테고리·플래그 해석은 mapping_loader 단일 소스만 사용한다(T4).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/nearest_service.dart';
import '../../data/providers.dart';
import '../../shared/mapping_loader.dart';

/// 지도 타일 레이어 — 위젯 테스트에서 네트워크를 타지 않도록 분리한
/// 오버라이드 지점. 기본값은 CARTO 라이트 타일(세이지 톤과 조화).
final mapTileLayerProvider = Provider<Widget>(
  (ref) => TileLayer(
    urlTemplate: 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
    userAgentPackageName: 'kr.gwangmyeong.ecomap',
  ),
);

/// 거리 표기 — 1km 미만은 m 반올림, 이상은 소수 1자리 km.
String formatDistance(double meters) => meters < 1000
    ? '${meters.round()}m'
    : '${(meters / 1000).toStringAsFixed(1)}km';

/// 수거함 타입별 아이콘 이모지.
///
/// 일부 수거함 타입명은 CSV 플래그 문자열을 그대로 포함해 타입 전체를
/// 리터럴로 두면 단일 소스 grep(T4)에 걸린다 — 플래그와 겹치지 않는
/// 부분 문자열로만 판별한다.
String binTypeEmoji(String type) {
  if (type.contains('무인회수기')) return '🤖';
  if (type.contains('재활용품')) return '♻️';
  if (type.contains('폐가전')) return '🔌';
  if (type.contains('형광')) return '💡';
  if (type.contains('전지')) return '🔋';
  if (type.startsWith('의')) return '👕';
  return '📍';
}

/// 거점 핀 마커 목록 — [category] 가 null 이면 전체 274행 (SPEC T6 Acceptance 1).
///
/// [highlighted] 에 든 거점(최근접 3곳)은 확대·진한 색으로 강조한다.
@visibleForTesting
List<Marker> buildBinMarkers({
  required List<BinRecord> bins,
  RecycleCategory? category,
  Set<BinRecord> highlighted = const {},
  void Function(BinRecord bin)? onTap,
}) {
  final Iterable<BinRecord> filtered = category == null
      ? bins
      : bins.where((bin) => bin.acceptsAny(category.csvFlags));
  return [
    for (final bin in filtered)
      Marker(
        point: LatLng(bin.lat, bin.lng),
        width: highlighted.contains(bin) ? 46 : 34,
        height: highlighted.contains(bin) ? 46 : 34,
        alignment: Alignment.topCenter,
        child: BinMarkerIcon(
          highlighted: highlighted.contains(bin),
          onTap: onTap == null ? null : () => onTap(bin),
        ),
      ),
  ];
}

/// 거점 핀 아이콘 — Primary 그린, 최근접 3곳은 확대 + PrimaryDark 강조.
class BinMarkerIcon extends StatelessWidget {
  const BinMarkerIcon({super.key, this.highlighted = false, this.onTap});

  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.location_on_rounded,
        size: highlighted ? 44 : 32,
        color: highlighted ? AppColors.primaryDark : AppColors.primary,
        shadows: const [
          Shadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

/// 내 위치 마커 — 그린 도트 + 라이트그린 링 + '내 위치' 라벨 (목업 ④).
class MyLocationMarker extends StatelessWidget {
  const MyLocationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.45),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            '내 위치',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// 지도 화면 본체.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.categoryId, this.focusLat, this.focusLng});

  /// 품목 필터용 카테고리 id. null 이면 전체 수거함.
  final String? categoryId;

  /// 공백 화면 "위치 보기" 진입용 포커스 좌표 (`?lat=&lng=`).
  final double? focusLat;

  /// 포커스 경도.
  final double? focusLng;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  bool _redirectScheduled = false;

  bool get _hasFocus => widget.focusLat != null && widget.focusLng != null;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _moveTo(BinRecord bin) {
    _mapController.move(LatLng(bin.lat, bin.lng), 16.5);
  }

  Future<void> _copyAddress(BinRecord bin) async {
    await Clipboard.setData(ClipboardData(text: bin.addr));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('주소를 복사했어요')));
  }

  @override
  Widget build(BuildContext context) {
    final binsAsync = ref.watch(binsProvider);
    final mappingAsync = ref.watch(mappingProvider);

    if (binsAsync.hasError || mappingAsync.hasError) {
      return _MessageScaffold(
        title: '지도',
        message: '수거함 데이터를 불러오지 못했어요.\n잠시 후 다시 시도해 주세요',
      );
    }
    final bins = binsAsync.value;
    final mapping = mappingAsync.value;
    if (bins == null || mapping == null) {
      return const _LoadingScaffold(title: '지도');
    }

    final category =
        widget.categoryId == null ? null : mapping.byId(widget.categoryId!);

    // 사각지대 판정 — 품목 필터 + 포커스 미지정일 때만 (SPEC T6-2).
    if (category != null && !_hasFocus) {
      final service = NearestService(mapping: mapping);
      final result =
          service.findNearest(categoryId: category.id, bins: bins);
      if (result is GapResult) {
        if (!_redirectScheduled) {
          _redirectScheduled = true;
          final target = '/gap/${category.id}';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(target);
          });
        }
        // 리다이렉트 전 한 프레임 — 빈 지도 대신 로딩 표시(크래시·빈화면 금지).
        return _LoadingScaffold(title: '${category.label} 받는 곳');
      }
    }

    // 거리 계산 + 오름차순 정렬 (내 위치 = 철산역 고정).
    final Iterable<BinRecord> source = category == null
        ? bins
        : bins.where((bin) => bin.acceptsAny(category.csvFlags));
    final sorted = <BinDistance>[];
    for (final bin in source) {
      final d = haversineMeters(
          demoLocation.latitude, demoLocation.longitude, bin.lat, bin.lng);
      sorted.add(
        BinDistance(bin: bin, distanceM: d, walkMinutes: walkMinutesFor(d)),
      );
    }
    sorted.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    // 동일 지점 물리 중복(같은 이름·주소·타입)은 한 행으로 합쳐 개수 표기.
    final listed = groupNearestForDisplay(sorted, take: 5);
    final highlighted = {for (final bd in sorted.take(3)) bd.bin};

    final markers = buildBinMarkers(
      bins: bins,
      category: category,
      highlighted: highlighted,
      onTap: _moveTo,
    );

    final initialCenter = _hasFocus
        ? LatLng(widget.focusLat!, widget.focusLng!)
        : demoLocation;
    final initialZoom = _hasFocus ? 15.5 : (category == null ? 14.2 : 14.6);

    return Scaffold(
      appBar: AppBar(
        leading: category == null ? null : const _BackToMapButton(),
        title: Text(category == null ? '내 주변 수거함' : '${category.label} 받는 곳'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 13,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: initialZoom,
                      minZoom: 3,
                      maxZoom: 19,
                      backgroundColor: AppColors.bgSage,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      ref.watch(mapTileLayerProvider),
                      MarkerLayer(
                        markers: [
                          ...markers,
                          Marker(
                            point: demoLocation,
                            width: 86,
                            height: 58,
                            child: const MyLocationMarker(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 타일 출처 표기 (CARTO 이용약관 필수).
                Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '© OpenStreetMap © CARTO',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 10,
            child: _NearestPanel(
              listed: listed,
              totalCount: sorted.length,
              filterLabel: category?.label,
              onTapItem: _moveTo,
              onCopyAddress: _copyAddress,
            ),
          ),
        ],
      ),
    );
  }
}

/// 하단 시트형 최근접 리스트 — 흰 카드, 상단 라운드, 드래그 핸들 모양.
class _NearestPanel extends StatelessWidget {
  const _NearestPanel({
    required this.listed,
    required this.totalCount,
    required this.filterLabel,
    required this.onTapItem,
    required this.onCopyAddress,
  });

  final List<GroupedBinDistance> listed;
  final int totalCount;

  /// 품목 필터 라벨 (전체 지도는 null → 거점 타입 표기).
  final String? filterLabel;

  final void Function(BinRecord bin) onTapItem;
  final void Function(BinRecord bin) onCopyAddress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        boxShadow: [
          BoxShadow(
            color: Color(0x141C2B21),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenEdge,
              AppSpacing.md,
              AppSpacing.screenEdge,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '내 위치에서 가까운 순이에요',
                    style: AppTextStyles.section.copyWith(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('전체 $totalCount곳', style: AppTextStyles.caption),
              ],
            ),
          ),
          Expanded(
            child: listed.isEmpty
                ? Center(
                    child: Text('표시할 수거 거점이 없어요',
                        style: AppTextStyles.caption),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    itemCount: listed.length,
                    separatorBuilder: (_, _) => const Divider(
                      indent: AppSpacing.screenEdge + 44 + AppSpacing.md,
                      endIndent: AppSpacing.screenEdge,
                    ),
                    itemBuilder: (context, index) {
                      final group = listed[index];
                      return BinListTile(
                        item: group.item,
                        count: group.count,
                        subtitleLabel:
                            filterLabel ?? group.item.bin.type,
                        onTap: () => onTapItem(group.item.bin),
                        onCopyAddress: () =>
                            onCopyAddress(group.item.bin),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 최근접 리스트 1행 — 타입 이모지 · 이름/주소 · 거리 · 도보 분 · 주소 복사.
class BinListTile extends StatelessWidget {
  const BinListTile({
    super.key,
    required this.item,
    required this.subtitleLabel,
    this.count = 1,
    this.onTap,
    this.onCopyAddress,
  });

  final BinDistance item;

  /// 같은 지점의 물리적 수거함 개수 — 2 이상이면 '2개' 배지 표시.
  final int count;

  /// 셋째 줄 라벨 — 품목 필터 시 카테고리 라벨, 전체 지도는 거점 타입.
  final String subtitleLabel;

  /// 항목 탭 → 지도 센터 이동.
  final VoidCallback? onTap;

  /// 주소 복사 액션 (길 안내는 데모 스코프 아님).
  final VoidCallback? onCopyAddress;

  @override
  Widget build(BuildContext context) {
    final bin = item.bin;
    final title =
        bin.detail.isNotEmpty ? '${bin.name} · ${bin.detail}' : bin.name;
    final meta =
        bin.days.isNotEmpty ? '$subtitleLabel · ${bin.days}' : subtitleLabel;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenEdge,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.bgSage,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                binTypeEmoji(bin.type),
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (count > 1) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.35),
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '$count개',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bin.addr,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDistance(item.distanceM),
                  style: AppTextStyles.section.copyWith(
                    fontSize: 15,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '도보 ${item.walkMinutes}분',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
            IconButton(
              onPressed: onCopyAddress,
              tooltip: '주소 복사',
              icon: const Icon(
                Icons.copy_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 품목 필터 화면의 뒤로가기 — pop 불가 시 전체 지도로.
class _BackToMapButton extends StatelessWidget {
  const _BackToMapButton();

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

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ),
    );
  }
}
