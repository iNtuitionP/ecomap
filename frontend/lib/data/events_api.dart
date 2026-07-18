/// 이벤트 로깅 API — RECOG_EVENTS 스키마(SPEC T7) 정합 인터페이스.
///
/// 데모 기본 구현은 [InMemoryEventLogger](웹/테스트용). 8월에 로컬 SQLite →
/// FastAPI 이관 시 [EventLogger] 구현체만 교체한다(호출부 불변).
library;

/// 인식 이벤트 1건 — RECOG_EVENTS 행과 1:1 (id/ts는 저장소가 부여).
class RecognitionEvent {
  const RecognitionEvent({
    required this.ts,
    required this.category,
    required this.csvFlag,
    required this.confidence,
    required this.manualFallback,
    required this.lat,
    required this.lng,
    required this.dong,
    required this.installId,
    required this.sessionId,
  });

  final DateTime ts;

  /// 8카테고리 id (mapping.json 체계).
  final String category;

  /// 매핑된 CSV 플래그 (mapping_loader 산출값 — 호출부가 리터럴 금지).
  final String csvFlag;

  final double confidence;

  /// 저신뢰도 수동 선택 fallback 여부.
  final bool manualFallback;

  final double lat;
  final double lng;
  final String dong;

  /// 앱 첫 실행 시 생성한 익명 UUID.
  final String installId;

  final String sessionId;
}

/// 사각지대 알리기(시민 제보) 이벤트 1건 — T6 빈상태 화면의 CTA.
class CivicReportEvent {
  const CivicReportEvent({
    required this.ts,
    required this.dong,
    required this.item,
  });

  final DateTime ts;
  final String dong;

  /// 품목명 (CSV 플래그 체계 — 데이터에서 온 값).
  final String item;
}

/// 이벤트 로거 인터페이스.
abstract interface class EventLogger {
  /// 인식/수동선택 1건 적재 (RECOG_EVENTS 스키마).
  Future<void> logRecognition({
    required String category,
    required String csvFlag,
    required double confidence,
    required bool manualFallback,
    required double lat,
    required double lng,
    required String dong,
    required String installId,
    required String sessionId,
  });

  /// "이 사각지대를 광명시에 알리기" 1건 적재.
  Future<void> logCivicReport({required String dong, required String item});
}

/// 메모리 적재 기본 구현 — 웹 데모·테스트용 (영속화 없음).
class InMemoryEventLogger implements EventLogger {
  final List<RecognitionEvent> recognitionEvents = [];
  final List<CivicReportEvent> civicReports = [];

  @override
  Future<void> logRecognition({
    required String category,
    required String csvFlag,
    required double confidence,
    required bool manualFallback,
    required double lat,
    required double lng,
    required String dong,
    required String installId,
    required String sessionId,
  }) async {
    recognitionEvents.add(
      RecognitionEvent(
        ts: DateTime.now(),
        category: category,
        csvFlag: csvFlag,
        confidence: confidence,
        manualFallback: manualFallback,
        lat: lat,
        lng: lng,
        dong: dong,
        installId: installId,
        sessionId: sessionId,
      ),
    );
  }

  @override
  Future<void> logCivicReport({
    required String dong,
    required String item,
  }) async {
    civicReports.add(
      CivicReportEvent(ts: DateTime.now(), dong: dong, item: item),
    );
  }
}
