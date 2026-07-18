// 데이터 레이어 · Riverpod 프로바이더 배선 — 실제 에셋으로 end-to-end 읽기.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecomap/data/events_api.dart';
import 'package:ecomap/data/nearest_service.dart';
import 'package:ecomap/data/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('binsProvider → 274행', () async {
    final bins = await container.read(binsProvider.future);
    expect(bins, hasLength(274));
  });

  test('mappingProvider → 8카테고리 + threshold 0.7', () async {
    final mapping = await container.read(mappingProvider.future);
    expect(mapping.categories, hasLength(8));
    expect(mapping.confidenceThreshold, 0.7);
  });

  test('rulesProvider → 카테고리 id 전부에 배출 단계 존재', () async {
    final mapping = await container.read(mappingProvider.future);
    final rules = await container.read(rulesProvider.future);
    expect(
      rules.keys.toSet(),
      mapping.categories.map((c) => c.id).toSet(),
    );
  });

  test('policyCardsProvider → 카드 23건 내림차순', () async {
    final doc = await container.read(policyCardsProvider.future);
    expect(doc.cards, hasLength(23));
    for (var i = 1; i < doc.cards.length; i++) {
      expect(doc.cards[i].severityScore,
          lessThanOrEqualTo(doc.cards[i - 1].severityScore));
    }
  });

  test('nearestServiceProvider → 실데이터로 최근접 산출', () async {
    final service = await container.read(nearestServiceProvider.future);
    final bins = await container.read(binsProvider.future);
    final result = service.findNearest(categoryId: 'pet', bins: bins);
    expect(result, isA<NearbyResult>());
  });

  test('eventLoggerProvider → 기본 InMemoryEventLogger', () {
    final logger = container.read(eventLoggerProvider);
    expect(logger, isA<InMemoryEventLogger>());
  });

  test('eventLoggerProvider — 같은 컨테이너에서 동일 인스턴스 유지', () async {
    final logger = container.read(eventLoggerProvider) as InMemoryEventLogger;
    await logger.logCivicReport(dong: '철산동', item: '스티로폼');
    final again = container.read(eventLoggerProvider) as InMemoryEventLogger;
    expect(identical(logger, again), isTrue);
    expect(again.civicReports, hasLength(1));
  });

  test('installIdProvider → UUID 생성, 재조회 시 동일값', () async {
    final id = await container.read(installIdProvider.future);
    expect(id, isNotEmpty);

    // 같은 컨테이너에서는 FutureProvider가 캐시되어 동일 Future/값을 반환.
    final again = await container.read(installIdProvider.future);
    expect(again, id);
  });

  test('installIdProvider → 새 컨테이너(앱 재실행 흉내)에서도 동일값(영속)', () async {
    final id = await container.read(installIdProvider.future);

    final freshContainer = ProviderContainer();
    addTearDown(freshContainer.dispose);
    final idAfterRestart = await freshContainer.read(installIdProvider.future);

    expect(idAfterRestart, id);
  });

  test('sessionIdProvider → 값 존재, 같은 컨테이너에서는 고정', () {
    final id = container.read(sessionIdProvider);
    expect(id, isNotEmpty);
    expect(container.read(sessionIdProvider), id);
  });

  test('sessionIdProvider → 컨테이너(=앱 실행)마다 다른 값', () {
    final id = container.read(sessionIdProvider);

    final otherContainer = ProviderContainer();
    addTearDown(otherContainer.dispose);
    final otherId = otherContainer.read(sessionIdProvider);

    expect(otherId, isNot(id));
  });
}
