// T5 · recognition-flow — 인식 서비스 단위 테스트.
//
// 검증: (1) API 키 유무 → Demo/Claude 자동 선택, (2) 데모 결정적 값,
// (3) Claude 요청 계약(헤더·모델·tool 강제·enum 주입·base64 이미지),
// (4) 응답 파싱, (5) 에러 → RecognitionException (수동선택 폴백 계약).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ecomap/services/recognition/claude_vision_service.dart';
import 'package:ecomap/services/recognition/recognition_providers.dart';
import 'package:ecomap/services/recognition/recognition_service.dart';
import 'package:ecomap/shared/mapping_loader.dart';

/// 동기화된 실제 매핑 에셋 (flutter test cwd = frontend/).
RecycleMapping loadMapping() => RecycleMapping.fromJson(
      jsonDecode(File('assets/data/mapping.json').readAsStringSync())
          as Map<String, dynamic>,
    );

/// 지정한 카테고리/신뢰도로 tool_use 응답을 흉내내는 MockClient.
MockClient toolUseClient({
  required String categoryId,
  required num confidence,
  void Function(http.Request request)? onRequest,
}) {
  return MockClient((request) async {
    onRequest?.call(request);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final toolName =
        ((body['tools'] as List).first as Map<String, dynamic>)['name'];
    return http.Response(
      jsonEncode({
        'content': [
          {
            'type': 'tool_use',
            'id': 'toolu_test',
            'name': toolName,
            'input': {'category_id': categoryId, 'confidence': confidence},
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

void main() {
  final mapping = loadMapping();

  group('createRecognitionService — 키 유무 분기', () {
    test('키 없음 → DemoRecognitionService (데모 모드)', () {
      final service = createRecognitionService(apiKey: '', mapping: mapping);
      expect(service, isA<DemoRecognitionService>());
    });

    test('키 있음 → ClaudeVisionService', () {
      final service =
          createRecognitionService(apiKey: 'sk-test', mapping: mapping);
      expect(service, isA<ClaudeVisionService>());
    });
  });

  group('DemoRecognitionService', () {
    test('사진 없이도 데모 각본 결정적 값(pet 0.96)을 반환한다', () async {
      final service =
          DemoRecognitionService(mapping: mapping, delay: Duration.zero);
      final result = await service.recognize();
      expect(result.categoryId, 'pet');
      expect(result.confidence, 0.96);
      // 단일 소스 검증: 반환 id는 mapping.json에 실존.
      expect(mapping.byId(result.categoryId), isNotNull);
    });

    test('이미지 바이트를 넘겨도 동일한 결정적 값', () async {
      final service =
          DemoRecognitionService(mapping: mapping, delay: Duration.zero);
      final result =
          await service.recognize(imageBytes: Uint8List.fromList([1, 2, 3]));
      expect(result.categoryId, 'pet');
      expect(result.confidence, 0.96);
    });
  });

  group('ClaudeVisionService — 요청 계약', () {
    test('헤더·모델·tool 강제·카테고리 enum·base64 이미지가 계약대로 나간다', () async {
      final imageBytes = Uint8List.fromList(List.generate(32, (i) => i));
      http.Request? captured;
      final service = ClaudeVisionService(
        apiKey: 'sk-test-key',
        mapping: mapping,
        httpClient: toolUseClient(
          categoryId: 'styrofoam',
          confidence: 0.83,
          onRequest: (request) => captured = request,
        ),
      );

      final result = await service.recognize(imageBytes: imageBytes);
      expect(result.categoryId, 'styrofoam');
      expect(result.confidence, closeTo(0.83, 1e-9));

      final request = captured!;
      expect(request.url.toString(), ClaudeVisionService.endpoint);
      expect(request.headers['x-api-key'], 'sk-test-key');
      expect(request.headers['anthropic-version'], '2023-06-01');
      expect(request.headers['content-type'], startsWith('application/json'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], ClaudeVisionService.model);

      // 구조화 출력: tool 강제.
      final toolChoice = body['tool_choice'] as Map<String, dynamic>;
      expect(toolChoice['type'], 'tool');
      expect(toolChoice['name'], ClaudeVisionService.toolName);

      // 카테고리 enum은 mapping.json 8종 그대로 주입 (리터럴 중복 정의 0).
      final tool = (body['tools'] as List).first as Map<String, dynamic>;
      final schema = tool['input_schema'] as Map<String, dynamic>;
      final props = schema['properties'] as Map<String, dynamic>;
      final enumIds =
          ((props['category_id'] as Map<String, dynamic>)['enum'] as List)
              .cast<String>();
      expect(enumIds, mapping.categories.map((c) => c.id).toList());
      expect(enumIds, hasLength(8));

      // 이미지는 base64로 동봉.
      final content = ((body['messages'] as List).first
          as Map<String, dynamic>)['content'] as List;
      final image = content.cast<Map<String, dynamic>>().firstWhere(
            (block) => block['type'] == 'image',
          );
      final source = image['source'] as Map<String, dynamic>;
      expect(source['type'], 'base64');
      expect(source['data'], base64Encode(imageBytes));
    });

    test('confidence는 0~1로 클램프된다', () async {
      final service = ClaudeVisionService(
        apiKey: 'sk-test',
        mapping: mapping,
        httpClient: toolUseClient(categoryId: 'can', confidence: 1.4),
      );
      final result =
          await service.recognize(imageBytes: Uint8List.fromList([1]));
      expect(result.confidence, 1.0);
    });
  });

  group('ClaudeVisionService — 에러 → RecognitionException (폴백 계약)', () {
    final bytes = Uint8List.fromList([1, 2, 3]);

    test('이미지 없음 → 예외', () {
      final service = ClaudeVisionService(
        apiKey: 'sk-test',
        mapping: mapping,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(
        () => service.recognize(),
        throwsA(isA<RecognitionException>()),
      );
    });

    test('HTTP 500 → 예외', () {
      final service = ClaudeVisionService(
        apiKey: 'sk-test',
        mapping: mapping,
        httpClient: MockClient(
          (_) async => http.Response('{"type":"error"}', 500),
        ),
      );
      expect(
        () => service.recognize(imageBytes: bytes),
        throwsA(isA<RecognitionException>()),
      );
    });

    test('네트워크 오류 → 예외', () {
      final service = ClaudeVisionService(
        apiKey: 'sk-test',
        mapping: mapping,
        httpClient: MockClient(
          (_) async => throw http.ClientException('연결 실패'),
        ),
      );
      expect(
        () => service.recognize(imageBytes: bytes),
        throwsA(isA<RecognitionException>()),
      );
    });

    test('tool_use 블록 없는 200 응답 → 예외', () {
      final service = ClaudeVisionService(
        apiKey: 'sk-test',
        mapping: mapping,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': '이건 구조화 출력이 아님'},
              ],
            }),
            200,
          ),
        ),
      );
      expect(
        () => service.recognize(imageBytes: bytes),
        throwsA(isA<RecognitionException>()),
      );
    });

    test('mapping에 없는 카테고리 id 응답 → 예외', () {
      final service = ClaudeVisionService(
        apiKey: 'sk-test',
        mapping: mapping,
        httpClient:
            toolUseClient(categoryId: 'unknown-category', confidence: 0.9),
      );
      expect(
        () => service.recognize(imageBytes: bytes),
        throwsA(isA<RecognitionException>()),
      );
    });
  });
}
