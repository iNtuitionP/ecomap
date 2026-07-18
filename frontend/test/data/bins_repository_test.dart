// 데이터 레이어 · BinsRepository — 실제 동기화 에셋(bins.geocoded.json) 274행 파싱.

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/data/bins_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BinsRepository (실제 에셋)', () {
    test('assets/data/bins.geocoded.json → 274행 전부 파싱', () async {
      final repo = BinsRepository(bundle: rootBundle);
      final bins = await repo.loadBins();
      expect(bins, hasLength(274));
    });

    test('274행 전부 좌표·법정동·15플래그 items 채워짐 (T1 동결 산출물 보증)',
        () async {
      final bins = await BinsRepository(bundle: rootBundle).loadBins();
      for (final bin in bins) {
        expect(bin.lat, isNot(0), reason: '${bin.addr}: lat 비어 있음');
        expect(bin.lng, isNot(0), reason: '${bin.addr}: lng 비어 있음');
        expect(bin.beopjeong.trim(), isNotEmpty,
            reason: '${bin.addr}: beopjeong 없음');
        expect(bin.items, hasLength(15),
            reason: '${bin.addr}: items 15플래그 아님');
        expect(['ok', 'manual', 'failed'], contains(bin.geocodeStatus),
            reason: '${bin.addr}: geocode_status 값 이상');
      }
    });

    test('재호출 시 캐시 재사용 (동일 인스턴스 반환)', () async {
      final repo = BinsRepository(bundle: rootBundle);
      final first = await repo.loadBins();
      final second = await repo.loadBins();
      expect(identical(first, second), isTrue);
    });
  });
}
