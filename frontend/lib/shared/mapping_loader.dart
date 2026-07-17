/// T4 · mapping-single-source — 인식 8카테고리 ↔ CSV 15플래그 매핑/룰 로더.
///
/// 정본은 repo의 `shared/mapping.json` · `shared/rules.json`.
/// `scripts/sync_app_assets.py` 가 `frontend/assets/data/` 로 복사하며,
/// 앱은 오직 이 로더를 통해 동기화된 에셋을 읽는다 — 카테고리·플래그를
/// Dart 코드에 중복 정의하지 않는다(SPEC T4 Acceptance 3: 중복 정의 0).
/// 동기화 일치는 `frontend/test/asset_sync_test.dart` 와
/// `scripts/contracts/tests/test_asset_sync.py` 가 검증한다.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// 동기화된 매핑 에셋 경로 (정본: shared/mapping.json).
const String mappingAssetPath = 'assets/data/mapping.json';

/// 동기화된 룰 에셋 경로 (정본: shared/rules.json).
const String rulesAssetPath = 'assets/data/rules.json';

/// 인식 카테고리 1건 — id/label/csv_flags (shared/mapping.json 의 categories 원소).
class RecycleCategory {
  const RecycleCategory({
    required this.id,
    required this.label,
    required this.csvFlags,
  });

  factory RecycleCategory.fromJson(Map<String, dynamic> json) {
    return RecycleCategory(
      id: json['id'] as String,
      label: json['label'] as String,
      csvFlags: (json['csv_flags'] as List<dynamic>).cast<String>(),
    );
  }

  final String id;
  final String label;
  final List<String> csvFlags;
}

/// shared/mapping.json 전체 — 8카테고리 + confidence_threshold.
class RecycleMapping {
  const RecycleMapping({
    required this.categories,
    required this.confidenceThreshold,
  });

  factory RecycleMapping.fromJson(Map<String, dynamic> json) {
    return RecycleMapping(
      categories: (json['categories'] as List<dynamic>)
          .map((e) => RecycleCategory.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      confidenceThreshold: (json['confidence_threshold'] as num).toDouble(),
    );
  }

  final List<RecycleCategory> categories;
  final double confidenceThreshold;

  /// id → 카테고리 (없으면 null).
  RecycleCategory? byId(String id) {
    for (final cat in categories) {
      if (cat.id == id) return cat;
    }
    return null;
  }
}

/// shared/rules.json 의 카테고리별 배출 단계.
class DisposalRule {
  const DisposalRule({required this.steps, required this.caution});

  factory DisposalRule.fromJson(Map<String, dynamic> json) {
    return DisposalRule(
      steps: (json['steps'] as List<dynamic>).cast<String>(),
      caution: json['caution'] as String,
    );
  }

  final List<String> steps;
  final String caution;
}

/// 동기화된 에셋에서 매핑·룰을 읽는 로더. 테스트에서 [AssetBundle] 주입 가능.
class MappingLoader {
  MappingLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<RecycleMapping> loadMapping() async {
    final raw = await _bundle.loadString(mappingAssetPath);
    return RecycleMapping.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<Map<String, DisposalRule>> loadRules() async {
    final raw = await _bundle.loadString(rulesAssetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (id, rule) =>
          MapEntry(id, DisposalRule.fromJson(rule as Map<String, dynamic>)),
    );
  }
}
