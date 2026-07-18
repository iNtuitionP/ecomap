// 데이터 레이어 · NearestService — 하버사인·필터·정렬·사각지대 판정 (SPEC T6).
//
// 수기 대조값은 독립 구현(Python haversine, R=6,371,000m)으로 계산해 고정했다:
//   기준점 = 철산역 (37.4757, 126.8677)
//   pet #1  : 경기도 광명시 오리로854번길 10 (무인회수기)  → 162.728m, 도보 3분
//   pet 중간: 경기도 광명시 시청로 20 (무인회수기)         → 455.603m, 도보 7분
//   pet 원거리: 광명시 광명로 928번길 18-20 (수거대)       → 1073.502m, 도보 17분
//   styrofoam 최근접: 일직동 505-20                        → 6403.615m, 도보 96분
//     (스티로폼 Y 거점은 시 전체 4곳 · 전부 일직동 → 철산역에서 1500m 초과 = tooFar)

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/core/constants.dart';
import 'package:ecomap/data/bins_repository.dart';
import 'package:ecomap/data/models.dart';
import 'package:ecomap/data/nearest_service.dart';
import 'package:ecomap/shared/mapping_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<BinRecord> bins;
  late NearestService service;

  setUpAll(() async {
    bins = await BinsRepository(bundle: rootBundle).loadBins();
    final mapping = await MappingLoader().loadMapping();
    service = NearestService(mapping: mapping);
  });

  group('haversineMeters', () {
    test('동일 지점 → 0', () {
      expect(haversineMeters(37.4757, 126.8677, 37.4757, 126.8677), 0);
    });

    test('철산역 → 최근접 pet 거점 좌표 = 162.728m (수기 대조)', () {
      final d = haversineMeters(
          37.4757, 126.8677, 37.4743690340131, 126.868466672165);
      expect(d, closeTo(162.728, 0.5));
    });
  });

  group('walkMinutesFor (도보 = 거리 / 67m/분, 올림)', () {
    test('162.728m → 3분', () => expect(walkMinutesFor(162.728), 3));
    test('455.603m → 7분', () => expect(walkMinutesFor(455.603), 7));
    test('6403.615m → 96분', () => expect(walkMinutesFor(6403.615), 96));
    test('정확히 67m → 1분', () => expect(walkMinutesFor(67), 1));
  });

  group('pet @ 철산역 — 최근접 정렬 정확성 (수기 계산 3건 대조)', () {
    late NearbyResult result;

    setUpAll(() {
      result = service.findNearest(categoryId: 'pet', bins: bins)
          as NearbyResult;
    });

    test('pet(무색페트병) Y 거점만 필터 → 63곳', () {
      expect(result.bins, hasLength(63));
      for (final bd in result.bins) {
        expect(bd.bin.accepts('무색페트병'), isTrue,
            reason: '${bd.bin.addr}: 무색페트병 N인데 포함됨');
      }
    });

    test('거리 오름차순 정렬', () {
      for (var i = 1; i < result.bins.length; i++) {
        expect(
          result.bins[i].distanceM,
          greaterThanOrEqualTo(result.bins[i - 1].distanceM),
          reason: 'index $i 에서 정렬 깨짐',
        );
      }
    });

    test('대조 1: 최근접 = 오리로854번길 10 무인회수기, 162.728m, 도보 3분', () {
      final first = result.bins.first;
      expect(first.bin.addr, '경기도 광명시 오리로854번길 10');
      expect(first.bin.name, '무인회수기');
      expect(first.bin.beopjeong, '철산동');
      expect(first.distanceM, closeTo(162.728, 0.5));
      expect(first.walkMinutes, 3);
    });

    test('대조 2: 시청로 20 무인회수기 = 455.603m, 도보 7분', () {
      final bd = result.bins.firstWhere(
          (b) => b.bin.addr == '경기도 광명시 시청로 20' && b.bin.name == '무인회수기');
      expect(bd.distanceM, closeTo(455.603, 0.5));
      expect(bd.walkMinutes, 7);
    });

    test('대조 3: 광명로 928번길 18-20 수거대 = 1073.502m, 도보 17분', () {
      final bd = result.bins
          .firstWhere((b) => b.bin.addr == '광명시 광명로 928번길 18-20');
      expect(bd.distanceM, closeTo(1073.502, 0.5));
      expect(bd.walkMinutes, 17);
    });
  });

  group('styrofoam @ 철산역 — tooFar 사각지대 판정', () {
    test('최근접 6403.6m > 1500m → GapResult.tooFar(일직동)', () {
      final result = service.findNearest(categoryId: 'styrofoam', bins: bins);
      expect(result, isA<TooFarGap>());
      final gap = result as TooFarGap;
      expect(gap.nearestDong, '일직동');
      expect(gap.nearestBin.beopjeong, '일직동');
      expect(gap.nearestBin.accepts('스티로폼'), isTrue);
      expect(gap.distanceM, closeTo(6403.615, 1.0));
      expect(gap.distanceM, greaterThan(gapRadiusMeters));
      expect(gap.walkMinutes, 96);
    });
  });

  group('커버리지 0 카테고리 — cityAbsent 판정', () {
    test('전 274행 플래그 N(식용유 = 죽은 매핑) 가상 카테고리 → GapResult.cityAbsent',
        () {
      // 식용유는 CSV Y=0행(SPEC: 죽은 매핑) — 시 전체에 거점이 없다.
      final phantomMapping = RecycleMapping(
        categories: const [
          RecycleCategory(id: 'phantom', label: '가상품목', csvFlags: ['식용유']),
        ],
        confidenceThreshold: 0.7,
      );
      final phantomService = NearestService(mapping: phantomMapping);
      final result =
          phantomService.findNearest(categoryId: 'phantom', bins: bins);
      expect(result, isA<CityAbsentGap>());
    });

    test('알 수 없는 categoryId → ArgumentError', () {
      expect(
        () => service.findNearest(categoryId: 'no-such-category', bins: bins),
        throwsArgumentError,
      );
    });
  });

  group('성능', () {
    test('274행 필터+정렬 < 50ms (SPEC T6 Acceptance 3)', () {
      // 워밍업(JIT) 1회 후 측정.
      service.findNearest(categoryId: 'pet', bins: bins);
      final sw = Stopwatch()..start();
      service.findNearest(categoryId: 'pet', bins: bins);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(50),
          reason: '274행 distance sort가 ${sw.elapsedMilliseconds}ms');
    });
  });

  group('기준 좌표 기본값', () {
    test('lat/lng 생략 시 demoLocation(철산역) 사용', () {
      final explicit = service.findNearest(
        categoryId: 'pet',
        bins: bins,
        lat: demoLocation.latitude,
        lng: demoLocation.longitude,
      ) as NearbyResult;
      final implicit =
          service.findNearest(categoryId: 'pet', bins: bins) as NearbyResult;
      expect(implicit.bins.first.distanceM, explicit.bins.first.distanceM);
      expect(demoLocation.latitude, 37.4757);
      expect(demoLocation.longitude, 126.8677);
    });
  });
}
