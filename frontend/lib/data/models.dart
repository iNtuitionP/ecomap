/// 데이터 레이어 모델 — 수거 거점(BinRecord)·정책카드(PolicyCard).
///
/// 원본: `data/bins.geocoded.json`(T1 동결 산출물) ·
/// `data/policy_cards.json`(T3 공백분석 산출물). 앱은 동기화된
/// `assets/data/` 사본만 읽는다.
///
/// **단일 소스 주의:** CSV 15플래그·8카테고리 문자열을 이 파일에 리터럴로
/// 두지 않는다 — 플래그 키는 JSON에서 온 값을 그대로 들고 다니고, 카테고리는
/// `lib/shared/mapping_loader.dart` 를 통해서만 해석한다.
library;

/// 수거 거점 1행 (bins.geocoded.json 원소).
class BinRecord {
  const BinRecord({
    required this.addr,
    required this.type,
    required this.name,
    required this.detail,
    required this.days,
    required this.items,
    required this.dept,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.beopjeong,
    required this.haengjeong,
    required this.geocodeStatus,
  });

  factory BinRecord.fromJson(Map<String, dynamic> json) {
    return BinRecord(
      addr: json['addr'] as String? ?? '',
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      days: json['days'] as String? ?? '',
      items: (json['items'] as Map<String, dynamic>)
          .map((flag, yn) => MapEntry(flag, yn == true)),
      dept: json['dept'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      beopjeong: json['beopjeong'] as String? ?? '',
      haengjeong: json['haengjeong'] as String? ?? '',
      geocodeStatus: json['geocode_status'] as String? ?? '',
    );
  }

  final String addr;
  final String type;
  final String name;
  final String detail;
  final String days;

  /// CSV 15플래그 → 수용 여부. 키는 JSON(정본 CSV 헤더) 그대로.
  final Map<String, bool> items;

  final String dept;
  final String phone;
  final double lat;
  final double lng;

  /// 법정동 (T1 역지오코딩 산출 — 문자열 파싱 아님).
  final String beopjeong;

  /// 행정동.
  final String haengjeong;

  /// ok | manual | failed (T1 계약).
  final String geocodeStatus;

  /// 이 거점이 [csvFlag] 품목을 받는가.
  bool accepts(String csvFlag) => items[csvFlag] ?? false;

  /// [csvFlags] 중 하나라도 받는가 (카테고리 → 복수 플래그 매핑용).
  bool acceptsAny(Iterable<String> csvFlags) => csvFlags.any(accepts);
}

/// 공백분석 정책카드 1건 (policy_cards.json 의 cards 원소).
class PolicyCard {
  const PolicyCard({
    required this.dong,
    required this.item,
    required this.categoryId,
    required this.action,
    required this.estEffect,
    required this.severity,
    required this.severityScore,
    required this.evidence,
  });

  factory PolicyCard.fromJson(Map<String, dynamic> json) {
    return PolicyCard(
      dong: json['dong'] as String? ?? '',
      item: json['item'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      estEffect: json['est_effect'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      severityScore: (json['severity_score'] as num?)?.toDouble() ?? 0,
      evidence: json['evidence'] as Map<String, dynamic>? ?? const {},
    );
  }

  final String dong;

  /// CSV 플래그 품목명 — JSON 산출물 값 그대로 (리터럴 재정의 금지).
  final String item;

  /// 8카테고리 id (mapping.json 의 id와 동일 체계).
  final String categoryId;

  /// 행정 액션 제안 문구.
  final String action;

  /// 추정 효과 (동 인구/세대수 공개데이터 기반 — T3 계약).
  final String estEffect;

  /// high | medium | low.
  final String severity;

  /// 정렬 키 (내림차순 = 심각한 것 먼저).
  final double severityScore;

  /// 산출 근거 (covered_dongs, bin_counts 등).
  final Map<String, dynamic> evidence;
}

/// policy_cards.json 문서 전체 (메타데이터 + 카드).
class PolicyCardsDocument {
  const PolicyCardsDocument({
    required this.unit,
    required this.source,
    required this.dongs,
    required this.items,
    required this.globalAbsentItems,
    required this.gapCellCount,
    required this.severityCriteria,
    required this.cards,
  });

  /// [cards] 는 severity_score **내림차순**으로 정렬해 보관한다.
  factory PolicyCardsDocument.fromJson(Map<String, dynamic> json) {
    final cards = (json['cards'] as List<dynamic>? ?? const [])
        .map((e) => PolicyCard.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.severityScore.compareTo(a.severityScore));
    return PolicyCardsDocument(
      unit: json['unit'] as String? ?? '',
      source: json['source'] as Map<String, dynamic>? ?? const {},
      dongs: (json['dongs'] as List<dynamic>? ?? const []).cast<String>(),
      items: (json['items'] as List<dynamic>? ?? const []).cast<String>(),
      globalAbsentItems:
          (json['global_absent_items'] as List<dynamic>? ?? const [])
              .cast<String>(),
      gapCellCount: (json['gap_cell_count'] as num?)?.toInt() ?? 0,
      severityCriteria:
          json['severity_criteria'] as Map<String, dynamic>? ?? const {},
      cards: List.unmodifiable(cards),
    );
  }

  /// 분석 단위 (예: 법정동).
  final String unit;

  /// 데이터 출처 (bins/mapping/dong_stats 경로·인구 기준월 등).
  final Map<String, dynamic> source;

  /// 분석 대상 동 목록.
  final List<String> dongs;

  /// 분석 대상 품목(CSV 플래그) 목록.
  final List<String> items;

  /// 시 전체에 거점이 0곳인 품목.
  final List<String> globalAbsentItems;

  /// 공백 셀(동×품목 Y거점 0) 개수.
  final int gapCellCount;

  /// 심각도 판정 기준 설명.
  final Map<String, dynamic> severityCriteria;

  /// severity_score 내림차순 정책카드.
  final List<PolicyCard> cards;
}
