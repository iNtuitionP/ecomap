/// 수거 거점 저장소 — 동기화된 에셋 `assets/data/bins.geocoded.json`(274행) 로드.
///
/// 정본은 repo의 `data/bins.geocoded.json`(T1 지오코딩 동결 산출물).
/// 테스트에서 [AssetBundle] 주입 가능. 파싱 결과는 1회 로드 후 캐시된다
/// (동결 파일이므로 런타임 변경 없음).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'models.dart';

/// 동기화된 수거 거점 에셋 경로.
const String binsAssetPath = 'assets/data/bins.geocoded.json';

class BinsRepository {
  BinsRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  List<BinRecord>? _cache;

  /// 274행 전부 파싱해 반환. 재호출 시 캐시 재사용.
  Future<List<BinRecord>> loadBins() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(binsAssetPath);
    final decoded = jsonDecode(raw) as List<dynamic>;
    final bins = List<BinRecord>.unmodifiable(
      decoded.map((e) => BinRecord.fromJson(e as Map<String, dynamic>)),
    );
    _cache = bins;
    return bins;
  }
}
