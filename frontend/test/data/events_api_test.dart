// 데이터 레이어 · EventLogger — RECOG_EVENTS 스키마 정합 + InMemory 구현 (SPEC T7 선행).

import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/data/events_api.dart';

void main() {
  group('InMemoryEventLogger', () {
    test('logRecognition — RECOG_EVENTS 스키마 필드 전부 적재', () async {
      final logger = InMemoryEventLogger();
      await logger.logRecognition(
        category: 'pet',
        csvFlag: '무색페트병',
        confidence: 0.92,
        manualFallback: false,
        lat: 37.4757,
        lng: 126.8677,
        dong: '철산동',
        installId: 'install-uuid-1',
        sessionId: 'session-1',
      );

      expect(logger.recognitionEvents, hasLength(1));
      final e = logger.recognitionEvents.single;
      expect(e.category, 'pet');
      expect(e.csvFlag, '무색페트병');
      expect(e.confidence, 0.92);
      expect(e.manualFallback, isFalse);
      expect(e.lat, 37.4757);
      expect(e.lng, 126.8677);
      expect(e.dong, '철산동');
      expect(e.installId, 'install-uuid-1');
      expect(e.sessionId, 'session-1');
      expect(e.ts.isAfter(DateTime(2026)), isTrue);
    });

    test('logRecognition — manual fallback 케이스 적재', () async {
      final logger = InMemoryEventLogger();
      await logger.logRecognition(
        category: 'etc',
        csvFlag: '플라스틱',
        confidence: 0.41,
        manualFallback: true,
        lat: 37.4757,
        lng: 126.8677,
        dong: '철산동',
        installId: 'install-uuid-1',
        sessionId: 'session-2',
      );
      expect(logger.recognitionEvents.single.manualFallback, isTrue);
    });

    test('logCivicReport — 사각지대 알리기 이벤트 적재', () async {
      final logger = InMemoryEventLogger();
      await logger.logCivicReport(dong: '철산동', item: '스티로폼');
      expect(logger.civicReports, hasLength(1));
      final r = logger.civicReports.single;
      expect(r.dong, '철산동');
      expect(r.item, '스티로폼');
      expect(r.ts.isAfter(DateTime(2026)), isTrue);
    });

    test('이벤트 누적 — 호출 순서 보존', () async {
      final logger = InMemoryEventLogger();
      for (var i = 0; i < 3; i++) {
        await logger.logRecognition(
          category: 'pet',
          csvFlag: '무색페트병',
          confidence: 0.9,
          manualFallback: false,
          lat: 0,
          lng: 0,
          dong: '철산동',
          installId: 'id',
          sessionId: 'session-$i',
        );
      }
      expect(logger.recognitionEvents, hasLength(3));
      expect(
        logger.recognitionEvents.map((e) => e.sessionId).toList(),
        ['session-0', 'session-1', 'session-2'],
      );
    });

    test('EventLogger 인터페이스로 다형 사용 가능', () {
      final EventLogger logger = InMemoryEventLogger();
      expect(logger, isA<EventLogger>());
    });
  });
}
