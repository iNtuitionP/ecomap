# -*- coding: utf-8 -*-
"""T3 · gap-analysis — 법정동 × 품목(15플래그) 공백분석 → 정책카드.

입력(단일 소스 — 매핑/플래그 상수를 코드에 중복 정의하지 않는다):
- data/bins.geocoded.json  : T1 동결 산출물. 품목 플래그 목록은 각 행의 items 키에서 유도.
- shared/mapping.json      : 인식 8카테고리 ↔ CSV 플래그 역매핑(카드 category_id).
- scripts/gap_analysis/dong_stats.json : 법정동별 주민등록 인구·세대(행정안전부, 2026.06).

출력:
- data/policy_cards.json            : 공백 셀(동×품목 Y거점 0) 정책카드, 심각도 내림차순.
- scripts/gap_analysis/gaps_report.md : 매트릭스·전역 부재·심각도 기준 명문화 리포트.

규칙:
- 분석 단위 = 법정동(beopjeong 필드 소비 — 주소 문자열 파싱 금지). T2 게이트 결정.
- 시 전역 Y=0 품목(예: 식용유)은 '전역 부재'로 분류 — 동별 카드 제외, 리포트 별도 섹션.
- est_effect는 dong_stats 기반 계산식으로만 산출(수기 숫자 하드코딩 금지).
  통계 없는 동은 정성 문구 + 데이터 부재 명시.
- 산출은 결정적(타임스탬프 없음) — 동결 커밋·스냅샷 pin 가능.
"""
import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
BINS_PATH = REPO_ROOT / "data" / "bins.geocoded.json"
MAPPING_PATH = REPO_ROOT / "shared" / "mapping.json"
STATS_PATH = REPO_ROOT / "scripts" / "gap_analysis" / "dong_stats.json"
CARDS_OUT_PATH = REPO_ROOT / "data" / "policy_cards.json"
REPORT_OUT_PATH = REPO_ROOT / "scripts" / "gap_analysis" / "gaps_report.md"

# ── 심각도 파라미터 ─────────────────────────────────────────────────────────
# 품목 중요도 가중치(분석 정책 파라미터 — mapping.json의 카테고리↔플래그 매핑을
# 중복 정의하는 것이 아니며, 플래그 우주도 데이터 items 키에서 유도한다).
# 근거(gaps_report.md에 명문화):
#   3 = 전용 거점 의존도 높음: 스티로폼(부피 큰 포장재, 전용함 없으면 배출 곤란),
#       무색페트병(별도 분리배출 의무 품목, 전용함 필요)
#   1 = 대체 배출 수단 존재/특수 저빈도: 일반쓰레기(종량제 문전수거),
#       건전지·형광등(유해폐기물 별도 체계), 소형전자제품(무상 방문수거 등), 식용유
#   2 = 그 외 일상 재활용 품목(기본값)
ITEM_WEIGHTS = {
    "스티로폼": 3,
    "무색페트병": 3,
    "일반쓰레기": 1,
    "건전지": 1,
    "형광등": 1,
    "소형전자제품": 1,
    "식용유": 1,
}
DEFAULT_ITEM_WEIGHT = 2
SEVERITY_HIGH = 0.45   # score ≥ 0.45 → high
SEVERITY_MEDIUM = 0.10  # score ≥ 0.10 → medium, 미만 → low


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def collect_flags(bins):
    """플래그 목록을 데이터 items 키에서 유도(코드 상수 금지). 전 행 키셋 일치 검증."""
    flags = list(bins[0]["items"].keys())
    flag_set = set(flags)
    for i, row in enumerate(bins):
        if set(row["items"].keys()) != flag_set:
            raise ValueError(f"row {i}: items 키셋이 첫 행과 다름 — 동결 데이터 오염 의심")
    return flags


def build_matrix(bins, flags):
    """법정동(beopjeong 필드) × 품목 Y거점 개수 매트릭스. 주소 문자열 파싱 안 함."""
    dongs = sorted({row["beopjeong"] for row in bins if row.get("beopjeong")})
    matrix = {d: {f: 0 for f in flags} for d in dongs}
    for row in bins:
        dong = row.get("beopjeong")
        if not dong:
            continue
        for f in flags:
            if row["items"].get(f):
                matrix[dong][f] += 1
    return dongs, matrix


def reverse_category_map(mapping):
    """CSV 플래그 → 카테고리 id (mapping.json 단일 소스). 역매핑 유일성 검증."""
    rev = {}
    for cat in mapping["categories"]:
        for flag in cat["csv_flags"]:
            if flag in rev:
                raise ValueError(f"플래그 '{flag}'가 복수 카테고리에 매핑됨 — mapping.json 위반")
            rev[flag] = cat["id"]
    return rev


def item_weight(flag):
    return ITEM_WEIGHTS.get(flag, DEFAULT_ITEM_WEIGHT)


def severity_level(score):
    if score >= SEVERITY_HIGH:
        return "high"
    if score >= SEVERITY_MEDIUM:
        return "medium"
    return "low"


def _est_effect(dong, flag, stats):
    """dong_stats 기반 계산식 산출 — 수기 숫자 금지. 통계 없으면 정성 문구+데이터 부재."""
    entry = stats.get(dong)
    if not entry:
        return (
            f"{dong} 인구 통계 미확보(데이터 부재) — 정성 평가: "
            f"관내 {flag} 배출 거점이 없어 주민이 타 동 거점을 이용해야 함"
        )
    hh = entry["households"]
    pop = entry["population"]
    year = entry.get("year", "")
    return (
        f"약 {hh:,}세대({pop:,}명)가 {flag} 배출 거점 없이 생활 "
        f"(주민등록 {year} 기준)"
    )


def build_outputs(bins, mapping, dong_stats):
    """공백분석 본체(순수 함수). (policy_cards payload, gaps_report.md 본문) 반환."""
    flags = collect_flags(bins)
    dongs, matrix = build_matrix(bins, flags)
    rev_cat = reverse_category_map(mapping)
    stats = dong_stats.get("stats", {})
    meta = dong_stats.get("meta", {})

    total_pop = sum(stats[d]["population"] for d in dongs if d in stats)

    # 전역 부재: 시 전체 Y=0 품목 → 동별 공백이 아니라 시 전체 부재
    item_totals = {f: sum(matrix[d][f] for d in dongs) for f in flags}
    global_absent = [f for f in flags if item_totals[f] == 0]

    cards = []
    for flag in flags:
        if flag in global_absent:
            continue
        counts = {d: matrix[d][flag] for d in dongs}
        covered = sorted((d for d in dongs if counts[d] > 0), key=lambda d: (-counts[d], d))
        for dong in dongs:
            if counts[dong] > 0:
                continue  # 공백 아님
            entry = stats.get(dong)
            if entry and total_pop > 0:
                score = round((entry["population"] / total_pop) * item_weight(flag), 4)
            else:
                score = 0.0
            covered_str = ", ".join(f"{d}({counts[d]}곳)" for d in covered)
            action = (
                f"{dong} 내 {flag} 수거 거점 신설 또는 기존 수거함 품목 확대 검토 — "
                f"현재 시 전체 {flag} 거점 {item_totals[flag]}곳은 {covered_str} 소재, "
                f"{dong}은 0곳"
            )
            cards.append(
                {
                    "dong": dong,
                    "item": flag,
                    "category_id": rev_cat.get(flag),  # 건전지·형광등 등 앱 8카테고리 밖은 null
                    "action": action,
                    "est_effect": _est_effect(dong, flag, stats),
                    "severity": severity_level(score),
                    "severity_score": score,
                    "evidence": {
                        "covered_dongs": covered,
                        "bin_counts": counts,
                    },
                }
            )

    flag_index = {f: i for i, f in enumerate(flags)}
    cards.sort(key=lambda c: (-c["severity_score"], c["dong"], flag_index[c["item"]]))

    payload = {
        "unit": "beopjeong",
        "source": {
            "bins": "data/bins.geocoded.json",
            "bin_rows": len(bins),
            "mapping": "shared/mapping.json",
            "dong_stats": "scripts/gap_analysis/dong_stats.json",
            "population_as_of": meta.get("as_of"),
        },
        "dongs": dongs,
        "items": flags,
        "global_absent_items": global_absent,
        "gap_cell_count": len(cards),
        "severity_criteria": {
            "formula": "severity_score = (동 인구 / 분석 대상 법정동 인구 합) × 품목 중요도 가중치",
            "item_weights": {f: item_weight(f) for f in flags},
            "thresholds": {
                "high": f">= {SEVERITY_HIGH}",
                "medium": f">= {SEVERITY_MEDIUM}",
                "low": f"< {SEVERITY_MEDIUM}",
            },
        },
        "cards": cards,
    }
    report = _render_report(payload, matrix, item_totals, meta, stats)
    return payload, report


def _render_report(payload, matrix, item_totals, meta, stats):
    dongs = payload["dongs"]
    flags = payload["items"]
    cards = payload["cards"]
    global_absent = payload["global_absent_items"]
    n_high = sum(1 for c in cards if c["severity"] == "high")
    n_med = sum(1 for c in cards if c["severity"] == "medium")
    n_low = sum(1 for c in cards if c["severity"] == "low")

    lines = []
    a = lines.append
    a("# 공백분석 리포트 — 법정동 × 품목 커버리지 (T3)")
    a("")
    a("> 산출물 — 직접 수정 금지. `python scripts/gap_analysis/build_gaps.py` 재실행으로 갱신.")
    a("> 입력: `data/bins.geocoded.json`(T1 동결, "
      f"{payload['source']['bin_rows']}행) · `shared/mapping.json` · `scripts/gap_analysis/dong_stats.json`.")
    a("")
    a("## 1. 분석 단위 — 법정동 7개 (T2 게이트 결정)")
    a("")
    a("공백분석 단위는 **법정동**이며, T1 역지오코딩 산출물의 `beopjeong` 필드를 그대로 소비한다"
      "(주소 문자열 파싱 없음). 근거(상세: `scripts/geocode/verify_report.md`):")
    a("")
    a("- 그라운드트루스 트랙(지번 주소 15행 자기-검증): 법정동 정확도 **100% (15/15)** — Kakao와 무관한 독립 확인.")
    a("- 독립 역지오코딩 트랙(OSM Nominatim, 무작위 20행): 행정동 정확도 **95.0% (19/20)** — SPEC의 80% 게이트는 통과.")
    a("- 그러나 SPEC T3가 `beopjeong` 필드 소비를 명시하고 행정동 top-up은 Out of Scope(TODOS T-3)로 분류되어 있어, "
      "7월 데모 스코프는 **법정동 유지**가 기존 결정과 정합적. "
      "행정동 데이터는 8월 이후 top-up 근거로 쓸 만큼 신뢰도가 확보됨.")
    a("- 정직한 고지 — 불일치 2건: idx48(광명-금천구 경계, OSM 데이터 성김으로 인한 이상치), "
      "idx53(OSM 법정동 폴리곤과 불일치 1건, 원인 미확정).")
    a("")
    a("수거함 데이터에 등장하는 법정동은 7개: " + " · ".join(dongs) + ".")
    a("")
    a("## 2. 커버리지 매트릭스 (법정동 × 15품목, Y거점 개수)")
    a("")
    a("| 법정동 | " + " | ".join(flags) + " |")
    a("|---" * (len(flags) + 1) + "|")
    for d in dongs:
        cells = []
        for f in flags:
            n = matrix[d][f]
            cells.append(f"**{n}**" if n == 0 else str(n))
        a(f"| {d} | " + " | ".join(cells) + " |")
    a("")
    a("굵은 **0** = 해당 동에 해당 품목 Y거점 없음. 전역 부재 품목 열은 §3 참고.")
    a("")
    a("## 3. 전역 부재 품목 (시 전체 Y=0 — 동별 카드 제외)")
    a("")
    if global_absent:
        for f in global_absent:
            a(f"- **{f}**: 274행 전 행 Y=0. 특정 동의 공백이 아니라 **광명시 전체에 배출 거점이 없는 품목**이므로 "
              "동별 정책카드에서 제외하고 여기 별도 기재한다. "
              "(mapping.json에서도 '죽은 매핑'으로 명시된 품목 — 시 차원의 수거 체계 신설이 필요한 사안.)")
    else:
        a("- 없음.")
    a("")
    a("## 4. 심각도 산정 기준 (명문화)")
    a("")
    a("```")
    a(payload["severity_criteria"]["formula"])
    a("```")
    a("")
    a("- **인구 규모**: 행정안전부 주민등록 법정동별 인구(" + str(meta.get("as_of", "?")) + ") ÷ "
      "분석 대상 7개 법정동 인구 합계 = 동별 인구 비중. 인구가 큰 동의 공백일수록 영향 주민이 많다.")
    a("- **품목 중요도 가중치** (전용 거점 의존도 기준):")
    a("  - `3` — 스티로폼·무색페트병: 전용 거점 없이는 배출이 곤란한 품목"
      "(스티로폼=부피 큰 포장재, 무색페트병=별도 분리배출 의무 품목).")
    a("  - `1` — 일반쓰레기(종량제 문전수거 대체 존재)·건전지·형광등(유해폐기물 별도 체계)·"
      "소형전자제품(무상 방문수거 등 대체 경로)·식용유: 대체 배출 수단이 있거나 저빈도 특수 품목.")
    a("  - `2` — 그 외 일상 재활용 품목(기본값): 종이·종이팩·금속캔·고철·플라스틱·유리병·비닐·의류.")
    a(f"- **등급 임계값**: high ≥ {SEVERITY_HIGH} · medium ≥ {SEVERITY_MEDIUM} · low < {SEVERITY_MEDIUM}.")
    a("- 가중치·임계값은 분석 정책 파라미터로 `build_gaps.py`에 정의(매핑/플래그 상수의 중복 정의가 아님 — "
      "플래그 목록은 데이터 items 키, 카테고리 매핑은 mapping.json에서 각각 유도).")
    a("")
    a("## 5. 정책카드 산출 결과")
    a("")
    a(f"공백 셀(동×품목 Y거점 0, 전역 부재 제외) **{len(cards)}건** → 정책카드 {len(cards)}장 "
      f"(high {n_high} · medium {n_med} · low {n_low}). 전체: `data/policy_cards.json` (심각도 내림차순).")
    a("")
    a("| # | 심각도 | score | 법정동 | 품목 | 추정 효과 |")
    a("|---|---|---|---|---|---|")
    for i, c in enumerate(cards, 1):
        a(f"| {i} | {c['severity']} | {c['severity_score']} | {c['dong']} | {c['item']} | {c['est_effect']} |")
    a("")
    a("### 데모 클라이맥스 — 스티로폼")
    a("")
    sty_counts = {d: matrix[d].get("스티로폼", 0) for d in dongs}
    sty_covered = [d for d in dongs if sty_counts[d] > 0]
    a(f"스티로폼 Y거점은 시 전체 {item_totals.get('스티로폼', 0)}곳, 전부 "
      f"{' · '.join(sty_covered)} 소재. 나머지 {len(dongs) - len(sty_covered)}개 법정동은 0곳. "
      "인구 상위 동(광명동·철산동·하안동)이 모두 공백이라 스티로폼 카드가 심각도 최상위를 차지한다 — "
      "트래픽 0(RECOG_EVENTS 없음)에서도 산출되는 결과다.")
    a("")
    a("## 6. est_effect 계산식")
    a("")
    a("`약 {세대수:,}세대({인구:,}명)가 {품목} 배출 거점 없이 생활` — 수치는 전부 "
      "`dong_stats.json`(행정안전부 주민등록, " + str(meta.get("as_of", "?")) + ")에서 계산식으로 산출하며 "
      "카드에 수기 숫자를 하드코딩하지 않는다. 통계가 없는 동은 정성 문구에 '데이터 부재'를 명시한다.")
    a("")
    a("## 7. 인구 통계 출처·특이사항 (정직한 고지)")
    a("")
    a("- 출처: 행정안전부 주민등록 데이터개방 포털(rdoa.jumin.go.kr) '법정동별 주민등록 인구 및 세대현황' — "
      "법정동 단위 공식 집계 원자료(근사치 아님). 교차검증: 8개 법정동 합계 303,666명(2026.06) ≈ "
      "별도 출처 시 전체 303,479명(2026.05).")
    a("- **옥길동(533명)·가학동(641명)의 극소 인구는 조회 오류가 아님.** 법정동 경계가 도시개발 이전 구역을 "
      "유지하는 경우가 많아, 물리적으로 인접한 대단지가 지번상 광명동·소하동 등에 속할 수 있음(추정 — 미확정, "
      "상세는 `dong_stats.json` meta.caveat). 따라서 두 동의 공백 카드는 심각도 산식상 low로 밀리며, "
      "이는 의도된 결과다(등록 인구 기준 영향 주민이 실제로 적음).")
    a("- 일직동은 2021.11.29 소하2동에서 분리된 독립 행정동(법정동=행정동 동일 명칭).")
    a("")
    a("## 8. 한계·후속")
    a("")
    a("- 커버 반경(거점-주거지 거리) 미반영 — 동 단위 유무만 판정. 8월 RECOG_EVENTS 실트래픽 적재 후 "
      "수요 가중 공백분석으로 고도화 예정.")
    a("- 행정동(18~19개) 단위 top-up은 TODOS T-3 — 역지오코딩 행정동 신뢰도(95%)는 확보된 상태.")
    a("- 건전지·형광등은 앱 인식 8카테고리 밖(유해폐기물 별도 취급)이라 카드 `category_id`가 null일 수 있으나, "
      "현 데이터에서는 두 품목 모두 전 동 커버로 공백 카드 없음.")
    a("")
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description="T3 공백분석 — 법정동×품목 매트릭스 → 정책카드")
    parser.add_argument("--bins", default=str(BINS_PATH))
    parser.add_argument("--mapping", default=str(MAPPING_PATH))
    parser.add_argument("--stats", default=str(STATS_PATH))
    parser.add_argument("--out-cards", default=str(CARDS_OUT_PATH))
    parser.add_argument("--out-report", default=str(REPORT_OUT_PATH))
    args = parser.parse_args(argv)

    bins = load_json(args.bins)
    mapping = load_json(args.mapping)
    dong_stats = load_json(args.stats)

    payload, report = build_outputs(bins, mapping, dong_stats)

    with open(args.out_cards, "w", encoding="utf-8", newline="\n") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")
    with open(args.out_report, "w", encoding="utf-8", newline="\n") as f:
        f.write(report)

    print(f"[build_gaps] cards={len(payload['cards'])} "
          f"(high={sum(1 for c in payload['cards'] if c['severity'] == 'high')}) "
          f"global_absent={payload['global_absent_items']} -> {args.out_cards}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
