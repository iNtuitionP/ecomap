/// 최근접 수거함 서비스 — 카테고리→CSV 플래그 필터→하버사인 거리순 정렬 (SPEC T6).
///
/// 카테고리→플래그 해석은 **오직** [RecycleMapping](`lib/shared/mapping_loader.dart`)
/// 을 통한다 — 플래그 문자열을 여기 리터럴로 두지 않는다(단일 소스).
///
/// 판정 규칙:
/// - 해당 품목 Y 거점 0곳            → [CityAbsentGap] (시 전체 부재)
/// - 최근접이 [gapRadiusMeters] 초과 → [TooFarGap] (사각지대 — 시에 알리기 UX)
/// - 반경 이내                       → [NearbyResult] (거리 오름차순 전체 목록)
library;

import 'dart:math' as math;

import '../core/constants.dart';
import '../shared/mapping_loader.dart';
import 'models.dart';

/// 하버사인 대원거리 (m). 지구 반지름 R = 6,371,000m.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusM = 6371000.0;
  final phi1 = _radians(lat1);
  final phi2 = _radians(lat2);
  final dPhi = _radians(lat2 - lat1);
  final dLambda = _radians(lng2 - lng1);
  final a = math.pow(math.sin(dPhi / 2), 2) +
      math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dLambda / 2), 2);
  return 2 * earthRadiusM * math.asin(math.sqrt(a));
}

double _radians(double deg) => deg * math.pi / 180;

/// 도보 소요 (분) — ceil(거리 ÷ [walkSpeedMetersPerMinute]).
int walkMinutesFor(double distanceM) =>
    (distanceM / walkSpeedMetersPerMinute).ceil();

/// 거리 계산이 끝난 거점 1건.
class BinDistance {
  const BinDistance({
    required this.bin,
    required this.distanceM,
    required this.walkMinutes,
  });

  final BinRecord bin;
  final double distanceM;
  final int walkMinutes;
}

/// 지도 리스트 표시용 그룹 — 동일 지점의 물리적 중복 수거함을 한 행으로.
class GroupedBinDistance {
  const GroupedBinDistance({required this.item, required this.count});

  /// 그룹 대표(최근접) 거점.
  final BinDistance item;

  /// 같은 (이름·주소·타입) 수거함 개수 — 1이면 중복 없음.
  final int count;
}

/// 거리순 리스트를 표시용으로 그룹핑한다.
///
/// 동결 데이터는 물리적 수거함 개체를 보존하므로(같은 주소 수거대 2개 등)
/// 그대로 뿌리면 같은 행이 반복돼 버그처럼 보인다. 데이터는 건드리지 않고
/// (이름, 주소, 타입)이 같은 행만 합쳐 개수를 단다. [take]는 그룹 단위.
List<GroupedBinDistance> groupNearestForDisplay(
  List<BinDistance> sorted, {
  required int take,
}) {
  final byKey = <String, int>{}; // key → grouped 인덱스
  final grouped = <GroupedBinDistance>[];
  for (final bd in sorted) {
    final key = '${bd.bin.name}|${bd.bin.addr}|${bd.bin.type}';
    final existing = byKey[key];
    if (existing != null) {
      grouped[existing] = GroupedBinDistance(
        item: grouped[existing].item,
        count: grouped[existing].count + 1,
      );
      continue;
    }
    if (grouped.length >= take) continue; // 새 그룹은 take까지만
    byKey[key] = grouped.length;
    grouped.add(GroupedBinDistance(item: bd, count: 1));
  }
  return grouped;
}

/// [NearestService.findNearest] 결과 — [NearbyResult] 또는 [GapResult].
sealed class NearestResult {
  const NearestResult();
}

/// 반경 이내 거점 존재 — 거리 오름차순 목록.
class NearbyResult extends NearestResult {
  const NearbyResult({required this.bins});

  /// 해당 품목 Y 거점 전체, 거리 오름차순 (수정 불가 리스트).
  final List<BinDistance> bins;

  BinDistance get nearest => bins.first;
}

/// 사각지대 판정 (SPEC T6 Acceptance 2 — graceful, 크래시·빈화면 금지).
sealed class GapResult extends NearestResult {
  const GapResult();

  /// 시 전체에 해당 품목 거점이 0곳.
  const factory GapResult.cityAbsent() = CityAbsentGap;

  /// 거점은 있으나 최근접이 [gapRadiusMeters] 밖.
  const factory GapResult.tooFar({
    required BinRecord nearestBin,
    required String nearestDong,
    required double distanceM,
    required int walkMinutes,
  }) = TooFarGap;
}

/// 시(市) 전체 부재 — "광명시에 이 품목 거점이 없어요" 안내.
class CityAbsentGap extends GapResult {
  const CityAbsentGap();
}

/// 최근접 거점이 판정 반경 밖 — "가장 가까운 곳은 OO동" 안내.
class TooFarGap extends GapResult {
  const TooFarGap({
    required this.nearestBin,
    required this.nearestDong,
    required this.distanceM,
    required this.walkMinutes,
  });

  final BinRecord nearestBin;

  /// 최근접 거점의 법정동 (안내 카피 "가장 가까운 OO동"에 사용).
  final String nearestDong;

  final double distanceM;
  final int walkMinutes;
}

class NearestService {
  const NearestService({required this.mapping});

  /// 카테고리 id → CSV 플래그 해석용 단일 소스 (mapping_loader 산출).
  final RecycleMapping mapping;

  /// [categoryId] 품목을 받는 거점을 [lat],[lng] (생략 시 [demoLocation])
  /// 기준 거리 오름차순으로 판정한다. 알 수 없는 카테고리는 [ArgumentError].
  ///
  /// 274행 기준 < 50ms (SPEC T6 Acceptance 3 — 성능 테스트로 보증).
  NearestResult findNearest({
    required String categoryId,
    required List<BinRecord> bins,
    double? lat,
    double? lng,
  }) {
    final category = mapping.byId(categoryId);
    if (category == null) {
      throw ArgumentError.value(
          categoryId, 'categoryId', 'mapping.json에 없는 카테고리');
    }
    final originLat = lat ?? demoLocation.latitude;
    final originLng = lng ?? demoLocation.longitude;

    final matched = <BinDistance>[];
    for (final bin in bins) {
      if (!bin.acceptsAny(category.csvFlags)) continue;
      final d = haversineMeters(originLat, originLng, bin.lat, bin.lng);
      matched.add(
        BinDistance(bin: bin, distanceM: d, walkMinutes: walkMinutesFor(d)),
      );
    }

    if (matched.isEmpty) return const GapResult.cityAbsent();

    matched.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    final nearest = matched.first;
    if (nearest.distanceM > gapRadiusMeters) {
      return GapResult.tooFar(
        nearestBin: nearest.bin,
        nearestDong: nearest.bin.beopjeong,
        distanceM: nearest.distanceM,
        walkMinutes: nearest.walkMinutes,
      );
    }
    return NearbyResult(bins: List.unmodifiable(matched));
  }
}
