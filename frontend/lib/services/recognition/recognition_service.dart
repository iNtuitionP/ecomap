/// T5 · recognition-flow — 인식 서비스 인터페이스 + 데모 구현.
///
/// 이미지 바이트 → 8카테고리 id + confidence(0~1). 카테고리 체계는
/// 오직 [RecycleMapping](`lib/shared/mapping_loader.dart`)에서 온다 —
/// 라벨·CSV 플래그 문자열을 여기 리터럴로 두지 않는다(단일 소스).
///
/// 구현체:
/// - [DemoRecognitionService]: API 키 없음(데모 모드) — 촬영 없이도
///   결정적 결과를 반환해 데모 각본을 보장한다.
/// - `ClaudeVisionService`(claude_vision_service.dart): Claude 비전 1콜.
library;

import 'dart:typed_data';

import '../../shared/mapping_loader.dart';

/// 인식 결과 1건 — 카테고리 id(mapping.json 체계) + confidence 0.0~1.0.
class RecognitionResult {
  const RecognitionResult({required this.categoryId, required this.confidence});

  /// mapping.json 8카테고리 중 하나의 id.
  final String categoryId;

  /// 0.0~1.0. `>= confidence_threshold`(0.7)면 자동 인식, 미만이면 수동 선택.
  final double confidence;
}

/// 인식 실패 예외 — 화면은 이걸 잡아 수동 선택으로 graceful 폴백한다
/// (SPEC T5-4: 크래시·빈화면 금지).
class RecognitionException implements Exception {
  const RecognitionException(this.message);

  final String message;

  @override
  String toString() => 'RecognitionException: $message';
}

/// 인식 서비스 인터페이스. 프로바이더가 API 키 유무로 구현체를 고른다.
abstract interface class RecognitionService {
  /// [imageBytes]를 분류한다. 데모 구현은 바이트 없이도 동작한다.
  ///
  /// 실패 시 [RecognitionException] 등 예외를 던진다 — null 반환 없음.
  Future<RecognitionResult> recognize({Uint8List? imageBytes});
}

/// 데모 인식 서비스 — API 키가 없을 때 사용 (데모 각본용 결정적 값).
///
/// 1.2초 딜레이(실제 인식처럼 보이는 연출) 후 데모 카테고리를
/// confidence 0.96으로 반환한다. 사진이 없어도 동작한다.
class DemoRecognitionService implements RecognitionService {
  DemoRecognitionService({
    required this.mapping,
    this.delay = const Duration(milliseconds: 1200),
  });

  /// 데모 각본 카테고리 id — mapping.json 에 실존해야 한다.
  static const String demoCategoryId = 'pet';

  /// 데모 각본 confidence (threshold 0.7 이상 → 자동 인식 경로).
  static const double demoConfidence = 0.96;

  final RecycleMapping mapping;

  /// 인식 연출 딜레이 (테스트에서 [Duration.zero]로 주입).
  final Duration delay;

  @override
  Future<RecognitionResult> recognize({Uint8List? imageBytes}) async {
    await Future<void>.delayed(delay);
    // 단일 소스 검증: 데모 id가 mapping에 없으면 첫 카테고리로 안전 폴백.
    final category = mapping.byId(demoCategoryId) ?? mapping.categories.first;
    return RecognitionResult(
      categoryId: category.id,
      confidence: demoConfidence,
    );
  }
}
