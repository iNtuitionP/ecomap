/// T5 · recognition-flow — 인식 서비스 프로바이더 배선.
///
/// API 키(`--dart-define=ANTHROPIC_API_KEY=...`) 유무로 구현체를 자동
/// 선택한다: 키 있음 → [ClaudeVisionService], 없음 → [DemoRecognitionService]
/// (데모 각본용 결정적 값). 화면은 [recognitionServiceProvider]만 본다.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/providers.dart';
import '../../shared/mapping_loader.dart';
import 'claude_vision_service.dart';
import 'recognition_service.dart';

/// 빌드타임 임베드 API 키. 비어 있으면 데모 모드.
///
/// 데모는 앱 임베드(통제·데모 후 로테이트), 8월부터 프록시 뒤로(SPEC).
const String anthropicApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');

/// 키 유무로 구현체 선택 (테스트에서 직접 호출해 분기 검증).
RecognitionService createRecognitionService({
  required String apiKey,
  required RecycleMapping mapping,
  http.Client? httpClient,
}) {
  if (apiKey.isEmpty) {
    return DemoRecognitionService(mapping: mapping);
  }
  return ClaudeVisionService(
    apiKey: apiKey,
    mapping: mapping,
    httpClient: httpClient,
  );
}

/// 데모 모드 여부 — 스캔 화면의 '데모 품목으로 체험하기' 노출 조건.
final demoModeProvider = Provider<bool>((ref) => anthropicApiKey.isEmpty);

/// 인식 서비스 (매핑 로드 후 생성). 위젯 테스트 오버라이드 지점.
final recognitionServiceProvider = FutureProvider<RecognitionService>(
  (ref) async {
    final mapping = await ref.watch(mappingProvider.future);
    return createRecognitionService(
      apiKey: anthropicApiKey,
      mapping: mapping,
    );
  },
);

/// 마지막 촬영/선택 이미지 — 결과·수동선택 화면의 미리보기용.
class CapturedImageNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => null;

  // ignore: use_setters_to_change_properties
  void set(Uint8List? bytes) => state = bytes;
}

final capturedImageProvider =
    NotifierProvider<CapturedImageNotifier, Uint8List?>(
  CapturedImageNotifier.new,
);
