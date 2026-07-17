// T4 · mapping-single-source — 에셋 동기화 검증 (SPEC T4 Acceptance 3).
//
// 정본 shared/mapping.json·rules.json 과 앱 에셋 frontend/assets/data/ 의
// 사본이 일치하는지, 앱이 MappingLoader 로 같은 파일을 읽는지 검증한다.
// 사본이 어긋나면 scripts/sync_app_assets.py 재실행 후 커밋할 것.
//
// `flutter test` 는 패키지 루트(frontend/)에서 실행되므로 정본은 ../shared/.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap/shared/mapping_loader.dart';

/// 포맷 차이를 무시하도록 decode→encode 로 정규화해 비교한다.
String _normalizedJson(String path) {
  final raw = File(path).readAsStringSync();
  return jsonEncode(jsonDecode(raw));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('synced assets match canonical shared/ sources', () {
    test('mapping.json is in sync', () {
      expect(
        _normalizedJson('assets/data/mapping.json'),
        _normalizedJson('../shared/mapping.json'),
        reason: 'frontend/assets/data/mapping.json 이 정본과 다름 — '
            'scripts/sync_app_assets.py 를 실행해 재동기화하라',
      );
    });

    test('rules.json is in sync', () {
      expect(
        _normalizedJson('assets/data/rules.json'),
        _normalizedJson('../shared/rules.json'),
        reason: 'frontend/assets/data/rules.json 이 정본과 다름 — '
            'scripts/sync_app_assets.py 를 실행해 재동기화하라',
      );
    });
  });

  group('app reads the same synced files via MappingLoader', () {
    test('loadMapping: 8 categories, threshold 0.7, non-empty csv_flags',
        () async {
      final mapping = await MappingLoader().loadMapping();
      expect(mapping.categories, hasLength(8));
      expect(mapping.confidenceThreshold, 0.7);
      for (final cat in mapping.categories) {
        expect(cat.csvFlags, isNotEmpty,
            reason: 'category ${cat.id}: csv_flags 비어 있음');
      }
    });

    test('loadRules: keys == mapping category ids, steps/caution non-empty',
        () async {
      final loader = MappingLoader();
      final mapping = await loader.loadMapping();
      final rules = await loader.loadRules();
      expect(
        rules.keys.toSet(),
        mapping.categories.map((c) => c.id).toSet(),
      );
      for (final entry in rules.entries) {
        expect(entry.value.steps, isNotEmpty,
            reason: 'rules[${entry.key}]: steps 비어 있음');
        expect(entry.value.caution.trim(), isNotEmpty,
            reason: 'rules[${entry.key}]: caution 없음');
      }
    });
  });
}
