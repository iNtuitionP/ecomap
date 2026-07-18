/// T5 · recognition-flow — Claude 비전 인식 서비스 (SPEC Decision 2).
///
/// Messages API 1콜: 이미지(base64) + tool 강제(구조화 출력)로
/// 8카테고리 id + confidence를 받는다. 카테고리 enum·라벨은 전부
/// [RecycleMapping]에서 주입한다 — Dart 리터럴 금지(단일 소스).
///
/// 실패 정책(SPEC T5-4): 타임아웃 12초, HTTP/파싱 오류는 전부
/// [RecognitionException]으로 던지고 화면이 수동 선택으로 폴백한다.
/// 크래시·빈화면 금지.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../shared/mapping_loader.dart';
import 'recognition_service.dart';

/// Claude 비전 1콜 인식 서비스.
///
/// 데모는 앱 임베드 키(`--dart-define=ANTHROPIC_API_KEY=...`) — 데모 후
/// 로테이트, 8월부터 프록시 뒤로(SPEC Architecture). 키가 비어 있으면
/// 프로바이더가 이 클래스를 만들지 않는다.
class ClaudeVisionService implements RecognitionService {
  ClaudeVisionService({
    required this.apiKey,
    required this.mapping,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 12),
  }) : _http = httpClient ?? http.Client();

  /// Messages API 엔드포인트.
  static const String endpoint = 'https://api.anthropic.com/v1/messages';

  /// 모델 — SPEC Decision 2 (Claude 비전, Sonnet 계열).
  static const String model = 'claude-sonnet-5';

  /// 구조화 출력 강제용 tool 이름.
  static const String toolName = 'classify_recycling_category';

  final String apiKey;
  final RecycleMapping mapping;
  final Duration timeout;
  final http.Client _http;

  @override
  Future<RecognitionResult> recognize({Uint8List? imageBytes}) async {
    if (imageBytes == null || imageBytes.isEmpty) {
      throw const RecognitionException('이미지 없음 — Claude 비전 인식에는 사진이 필요합니다');
    }

    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse(endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode(_buildRequestBody(imageBytes)),
          )
          .timeout(timeout);
    } on RecognitionException {
      rethrow;
    } catch (e) {
      // 타임아웃·네트워크 오류 → 수동 선택 폴백 경로 (SPEC T5-4).
      throw RecognitionException('Claude API 호출 실패: $e');
    }

    if (response.statusCode != 200) {
      throw RecognitionException(
        'Claude API HTTP ${response.statusCode}: ${response.body}',
      );
    }
    return _parseResponse(utf8.decode(response.bodyBytes));
  }

  /// Messages API 요청 바디 — 이미지 1장 + tool 강제(구조화 출력).
  Map<String, dynamic> _buildRequestBody(Uint8List imageBytes) {
    final categoryIds =
        mapping.categories.map((c) => c.id).toList(growable: false);
    // 카테고리 카탈로그는 런타임에 mapping.json 라벨로 구성 (리터럴 0).
    final catalog =
        mapping.categories.map((c) => '- ${c.id}: ${c.label}').join('\n');

    return {
      'model': model,
      'max_tokens': 256,
      // 강제 tool_choice와 함께 딥씽킹은 불필요 — 지연·비용 절감(12초 예산).
      'thinking': {'type': 'disabled'},
      'tools': [
        {
          'name': toolName,
          'description': '사진 속 품목을 분리배출 카테고리 하나로 분류하고 확신도를 보고한다.',
          'strict': true,
          'input_schema': {
            'type': 'object',
            'properties': {
              'category_id': {
                'type': 'string',
                'enum': categoryIds,
                'description': '가장 가까운 분리배출 카테고리 id',
              },
              'confidence': {
                'type': 'number',
                'description': '분류 확신도. 0.0(전혀 모름)~1.0(확실) 사이 실수',
              },
            },
            'required': ['category_id', 'confidence'],
            'additionalProperties': false,
          },
        },
      ],
      'tool_choice': {'type': 'tool', 'name': toolName},
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': _mediaTypeOf(imageBytes),
                'data': base64Encode(imageBytes),
              },
            },
            {
              'type': 'text',
              'text': '사진 속 품목을 아래 분리배출 카테고리 중 하나로 분류해 주세요. '
                  '제품명·브랜드는 판단하지 말고 재질 카테고리만 판정합니다. '
                  '확신이 낮으면 confidence를 낮게 보고하세요.\n$catalog',
            },
          ],
        },
      ],
    };
  }

  /// 응답에서 tool_use 블록을 찾아 [RecognitionResult]로 변환.
  RecognitionResult _parseResponse(String body) {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw RecognitionException('Claude 응답 JSON 파싱 실패: $e');
    }

    final content = decoded['content'];
    if (content is! List) {
      throw const RecognitionException('Claude 응답에 content 배열 없음');
    }
    final toolUse = content.whereType<Map<String, dynamic>>().where(
          (block) => block['type'] == 'tool_use' && block['name'] == toolName,
        );
    if (toolUse.isEmpty) {
      throw const RecognitionException('Claude 응답에 tool_use 블록 없음');
    }

    final input = toolUse.first['input'];
    if (input is! Map<String, dynamic>) {
      throw const RecognitionException('tool_use input 형식 오류');
    }
    final categoryId = input['category_id'];
    final confidence = input['confidence'];
    if (categoryId is! String || mapping.byId(categoryId) == null) {
      throw RecognitionException('알 수 없는 카테고리 id: $categoryId');
    }
    if (confidence is! num) {
      throw const RecognitionException('confidence 숫자 아님');
    }
    return RecognitionResult(
      categoryId: categoryId,
      confidence: confidence.toDouble().clamp(0.0, 1.0),
    );
  }

  /// 매직 바이트로 media_type 추정 (image_picker 기본은 JPEG).
  static String _mediaTypeOf(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'image/gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
