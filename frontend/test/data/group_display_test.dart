// 지도 리스트 표시용 중복 그룹핑 — 동일 (이름·주소·타입) 수거함이 물리적으로
// 여러 개인 행(예: 철산3동 행정복지센터 수거대 ×2)을 한 줄로 합쳐 개수를 단다.
// 데이터는 개체 보존(SPEC T1 dedup 원칙), 화면 표시만 합친다.
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/data/models.dart';
import 'package:ecomap/data/nearest_service.dart';

BinRecord _bin(String name, String addr, String type, double lat, double lng) {
  return BinRecord.fromJson({
    'sigun': '경기도 광명시',
    'type': type,
    'name': name,
    'addr': addr,
    'detail': '',
    'days': '',
    'items': {'무색페트병': true},
    'dept': '자원순환과',
    'phone': '',
    'lat': lat,
    'lng': lng,
    'beopjeong': '철산동',
    'haengjeong': '철산3동',
    'geocode_status': 'ok',
  });
}

BinDistance _bd(BinRecord bin, double d) =>
    BinDistance(bin: bin, distanceM: d, walkMinutes: (d / 67).ceil());

void main() {
  test('동일 이름·주소·타입 수거함은 한 그룹으로 합쳐지고 개수가 달린다', () {
    final a1 = _bd(_bin('수거대', '광명시 철산로 56', '재활용품 분리배출함', 37.47, 126.86), 421);
    final a2 = _bd(_bin('수거대', '광명시 철산로 56', '재활용품 분리배출함', 37.47, 126.86), 421);
    final b = _bd(_bin('무인회수기', '광명시 철산로 56', '무인회수기', 37.47, 126.86), 421);
    final grouped = groupNearestForDisplay([a1, a2, b], take: 5);
    expect(grouped.length, 2);
    expect(grouped[0].count, 2); // 수거대 ×2 합침
    expect(grouped[1].count, 1); // 무인회수기는 타입이 달라 별도 행
  });

  test('그룹핑 후에도 거리 오름차순이 유지되고 take는 그룹 단위다', () {
    final near = _bd(_bin('회수기', '오리로854번길 10', '무인회수기', 37.476, 126.867), 163);
    final far1 = _bd(_bin('수거대', '철산로 56', '재활용품 분리배출함', 37.47, 126.86), 421);
    final far2 = _bd(_bin('수거대', '철산로 56', '재활용품 분리배출함', 37.47, 126.86), 421);
    final grouped = groupNearestForDisplay([near, far1, far2], take: 2);
    expect(grouped.length, 2);
    expect(grouped[0].item.bin.name, '회수기');
    expect(grouped[1].count, 2);
  });

  test('중복이 없으면 원래 리스트 그대로다', () {
    final a = _bd(_bin('A', '주소1', '재활용품 분리배출함', 37.1, 126.8), 100);
    final b = _bd(_bin('B', '주소2', '의류 수거함', 37.2, 126.9), 200);
    final grouped = groupNearestForDisplay([a, b], take: 5);
    expect(grouped.length, 2);
    expect(grouped.every((g) => g.count == 1), isTrue);
  });
}
