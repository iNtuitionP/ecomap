// 데이터 레이어 · 모델 단위 테스트 — BinRecord / PolicyCard fromJson.
//
// 주의: CSV 플래그·카테고리 리터럴은 테스트 픽스처로만 사용한다(단일 소스
// 강제는 lib/ 에만 적용 — scripts/contracts/tests/test_asset_sync.py 참조).

import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/data/models.dart';

void main() {
  group('BinRecord.fromJson', () {
    final json = <String, dynamic>{
      'sigun': '광명시',
      'type': '재활용품 분리배출함',
      'name': '수거대',
      'addr': '경기도 광명시 하안동 229',
      'detail': '',
      'days': '상시',
      'items': <String, dynamic>{
        '일반쓰레기': true,
        '종이': true,
        '종이팩': true,
        '금속캔': true,
        '고철': true,
        '플라스틱': true,
        '무색페트병': true,
        '유리병': true,
        '비닐': true,
        '스티로폼': false,
        '건전지': false,
        '형광등': false,
        '소형전자제품': false,
        '식용유': false,
        '의류': false,
      },
      'dept': '자원순환과',
      'phone': '02-2680-2836',
      'lat': 37.4563505138065,
      'lng': 126.879433399923,
      'beopjeong': '하안동',
      'haengjeong': '하안1동',
      'geocode_status': 'ok',
    };

    test('필드 전부 파싱 (addr/type/name/detail/days/dept/phone/좌표/동/status)',
        () {
      final bin = BinRecord.fromJson(json);
      expect(bin.addr, '경기도 광명시 하안동 229');
      expect(bin.type, '재활용품 분리배출함');
      expect(bin.name, '수거대');
      expect(bin.detail, '');
      expect(bin.days, '상시');
      expect(bin.dept, '자원순환과');
      expect(bin.phone, '02-2680-2836');
      expect(bin.lat, closeTo(37.4563505138065, 1e-9));
      expect(bin.lng, closeTo(126.879433399923, 1e-9));
      expect(bin.beopjeong, '하안동');
      expect(bin.haengjeong, '하안1동');
      expect(bin.geocodeStatus, 'ok');
    });

    test('items 15플래그 Map<String,bool> 파싱', () {
      final bin = BinRecord.fromJson(json);
      expect(bin.items, hasLength(15));
      expect(bin.items['무색페트병'], isTrue);
      expect(bin.items['스티로폼'], isFalse);
      expect(bin.items.values, everyElement(isA<bool>()));
    });

    test('accepts / acceptsAny — 플래그 수용 판정', () {
      final bin = BinRecord.fromJson(json);
      expect(bin.accepts('무색페트병'), isTrue);
      expect(bin.accepts('스티로폼'), isFalse);
      expect(bin.accepts('없는플래그'), isFalse);
      expect(bin.acceptsAny(['스티로폼', '금속캔']), isTrue);
      expect(bin.acceptsAny(['스티로폼', '식용유']), isFalse);
      expect(bin.acceptsAny(const <String>[]), isFalse);
    });
  });

  group('PolicyCard.fromJson', () {
    final json = <String, dynamic>{
      'dong': '광명동',
      'item': '스티로폼',
      'category_id': 'styrofoam',
      'action': '광명동 내 스티로폼 수거 거점 신설 검토',
      'est_effect': '약 37,949세대(87,546명)가 배출 거점 없이 생활',
      'severity': 'high',
      'severity_score': 0.8677,
      'evidence': <String, dynamic>{
        'covered_dongs': ['일직동'],
        'bin_counts': {'광명동': 0, '일직동': 4},
      },
    };

    test('필드 전부 파싱', () {
      final card = PolicyCard.fromJson(json);
      expect(card.dong, '광명동');
      expect(card.item, '스티로폼');
      expect(card.categoryId, 'styrofoam');
      expect(card.action, contains('스티로폼 수거 거점 신설'));
      expect(card.estEffect, contains('37,949세대'));
      expect(card.severity, 'high');
      expect(card.severityScore, closeTo(0.8677, 1e-9));
      expect(card.evidence['covered_dongs'], ['일직동']);
    });
  });
}
