/// 정책카드 저장소 — 동기화된 에셋 `assets/data/policy_cards.json` 로드 (SPEC T8 데이터).
///
/// 정본은 repo의 `data/policy_cards.json`(T3 공백분석 산출물, 동결 커밋).
/// cards 는 severity_score **내림차순**으로 정렬해 반환한다
/// (어드민 화면은 앞에서 Top N만 취하면 됨). 테스트에서 [AssetBundle] 주입 가능.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'models.dart';

/// 동기화된 정책카드 에셋 경로.
const String policyCardsAssetPath = 'assets/data/policy_cards.json';

class PolicyRepository {
  PolicyRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  PolicyCardsDocument? _cache;

  /// 문서 전체(메타데이터 + severity_score 내림차순 카드) 로드.
  /// 재호출 시 캐시 재사용.
  Future<PolicyCardsDocument> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(policyCardsAssetPath);
    final doc = PolicyCardsDocument.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _cache = doc;
    return doc;
  }
}
