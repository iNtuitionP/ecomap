// 데이터 레이어 · PolicyRepository — 실제 에셋(policy_cards.json) 로드·정렬 (SPEC T8 데이터).

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/data/policy_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PolicyRepository (실제 에셋)', () {
    test('assets/data/policy_cards.json → 카드 23건 + 메타데이터', () async {
      final doc = await PolicyRepository(bundle: rootBundle).load();
      expect(doc.cards, hasLength(23));
      expect(doc.unit, 'beopjeong');
      expect(doc.source, isNotEmpty);
      expect(doc.dongs, isNotEmpty);
      expect(doc.items, isNotEmpty);
      expect(doc.gapCellCount, greaterThan(0));
    });

    test('cards는 severity_score 내림차순', () async {
      final doc = await PolicyRepository(bundle: rootBundle).load();
      for (var i = 1; i < doc.cards.length; i++) {
        expect(
          doc.cards[i].severityScore,
          lessThanOrEqualTo(doc.cards[i - 1].severityScore),
          reason: 'index $i 에서 내림차순 깨짐',
        );
      }
    });

    test('Top 카드 = 광명동 스티로폼 high (데모 클라이맥스 데이터)', () async {
      final doc = await PolicyRepository(bundle: rootBundle).load();
      final top = doc.cards.first;
      expect(top.dong, '광명동');
      expect(top.categoryId, 'styrofoam');
      expect(top.severity, 'high');
      expect(top.severityScore, closeTo(0.8677, 1e-6));
      expect(top.action.trim(), isNotEmpty);
      expect(top.estEffect.trim(), isNotEmpty);
    });

    test('카드 전건 필수 필드 채워짐 + severity 값 정합', () async {
      final doc = await PolicyRepository(bundle: rootBundle).load();
      for (final card in doc.cards) {
        expect(card.dong.trim(), isNotEmpty);
        expect(card.item.trim(), isNotEmpty);
        expect(card.categoryId.trim(), isNotEmpty);
        expect(card.action.trim(), isNotEmpty);
        expect(card.estEffect.trim(), isNotEmpty);
        expect(['high', 'medium', 'low'], contains(card.severity));
      }
    });

    test('재호출 시 캐시 재사용 (동일 인스턴스 반환)', () async {
      final repo = PolicyRepository(bundle: rootBundle);
      final first = await repo.load();
      final second = await repo.load();
      expect(identical(first, second), isTrue);
    });
  });
}
