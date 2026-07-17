# -*- coding: utf-8 -*-
"""T3 · gap-analysis — build_gaps.py 테스트.

SPEC T3 Acceptance + 오케스트레이터 규칙 검증:
- 법정동(beopjeong 필드) × 15품목 매트릭스 → Y거점 0셀 = 공백 카드
- 시 전역 Y=0 품목(식용유)은 '전역 부재'로 분류, 동별 카드에서 제외
- 정책카드 ≥3건, 스티로폼 카드 필수(일직동 4곳뿐 — 실데이터)
- est_effect는 dong_stats 계산식 산출(수기 숫자 금지), 통계 없으면 정성 문구+데이터 부재 명시
- shared/mapping.json 단일 소스 실제 소비(코드 내 매핑 중복 정의 금지)
- 첫 산출 결과 스냅샷 pin(실제 산출 후 고정 — 허구 기대값 금지)
"""
import json
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from build_gaps import (  # noqa: E402
    BINS_PATH,
    MAPPING_PATH,
    STATS_PATH,
    CARDS_OUT_PATH,
    REPORT_OUT_PATH,
    REPO_ROOT,
    build_outputs,
    load_json,
)

SNAPSHOT_PATH = Path(__file__).resolve().parent / "snapshots" / "policy_cards.pinned.json"


# ---------------------------------------------------------------- 합성 픽스처

def mk_bin(dong, true_flags, all_flags, addr=""):
    """beopjeong=dong, true_flags만 Y인 합성 수거함 1행."""
    return {
        "addr": addr,
        "beopjeong": dong,
        "items": {f: (f in true_flags) for f in all_flags},
    }


SYN_FLAGS = ["스티로폼", "무색페트병", "식용유"]

SYN_MAPPING = {
    "categories": [
        {"id": "styrofoam", "label": "스티로폼", "csv_flags": ["스티로폼"]},
        {"id": "pet", "label": "무색 페트병", "csv_flags": ["무색페트병"]},
        {"id": "etc", "label": "기타", "csv_flags": ["식용유"]},
    ]
}


def syn_stats(**pops):
    """{dong: (population, households)} → dong_stats 구조."""
    return {
        "meta": {"as_of": "2026.06"},
        "stats": {
            d: {
                "population": p,
                "households": h,
                "year": "2026.06",
                "source": "synthetic",
            }
            for d, (p, h) in pops.items()
        },
    }


# ---------------------------------------------------------------- 매트릭스/공백

class TestMatrixAndGaps:
    def test_flags_derived_from_data_items_keys(self):
        """플래그 목록은 코드 상수가 아니라 데이터 items 키에서 유도(3플래그 합성도 동작)."""
        bins = [
            mk_bin("A동", ["스티로폼", "무색페트병"], SYN_FLAGS),
            mk_bin("B동", ["무색페트병"], SYN_FLAGS),
        ]
        payload, _ = build_outputs(bins, SYN_MAPPING, syn_stats(**{"A동": (100, 40), "B동": (100, 40)}))
        assert payload["items"] == SYN_FLAGS

    def test_beopjeong_field_consumed_not_addr_parsing(self):
        """주소 문자열에 오도성 동명을 넣어도 beopjeong 필드가 기준(문자열 파싱 금지 검증)."""
        bins = [
            mk_bin("소하동", ["스티로폼", "무색페트병"], SYN_FLAGS, addr="경기도 광명시 하안동 999"),
            mk_bin("하안동", ["무색페트병"], SYN_FLAGS, addr="경기도 광명시 소하동 1"),
        ]
        payload, _ = build_outputs(
            bins, SYN_MAPPING, syn_stats(**{"소하동": (100, 40), "하안동": (100, 40)})
        )
        gap = [c for c in payload["cards"] if c["item"] == "스티로폼"]
        assert len(gap) == 1
        assert gap[0]["dong"] == "하안동"  # addr가 아니라 beopjeong 기준
        assert gap[0]["evidence"]["covered_dongs"] == ["소하동"]

    def test_gap_cell_produces_card_with_evidence(self):
        bins = [
            mk_bin("A동", ["스티로폼", "무색페트병"], SYN_FLAGS),
            mk_bin("A동", ["스티로폼"], SYN_FLAGS),
            mk_bin("B동", ["무색페트병"], SYN_FLAGS),
        ]
        payload, _ = build_outputs(bins, SYN_MAPPING, syn_stats(**{"A동": (100, 40), "B동": (100, 40)}))
        cards = [c for c in payload["cards"] if c["item"] == "스티로폼"]
        assert len(cards) == 1
        card = cards[0]
        assert card["dong"] == "B동"
        assert card["category_id"] == "styrofoam"
        assert card["evidence"]["covered_dongs"] == ["A동"]
        assert card["evidence"]["bin_counts"] == {"A동": 2, "B동": 0}
        for key in ("dong", "item", "category_id", "action", "est_effect", "severity", "evidence"):
            assert key in card

    def test_global_absent_item_excluded_from_cards(self):
        """전 동 Y=0 품목은 동별 카드가 아니라 전역 부재로 분류."""
        bins = [
            mk_bin("A동", ["스티로폼"], SYN_FLAGS),
            mk_bin("B동", ["스티로폼", "무색페트병"], SYN_FLAGS),
        ]
        payload, report = build_outputs(
            bins, SYN_MAPPING, syn_stats(**{"A동": (100, 40), "B동": (100, 40)})
        )
        assert payload["global_absent_items"] == ["식용유"]
        assert all(c["item"] != "식용유" for c in payload["cards"])
        assert "전역 부재" in report and "식용유" in report


# ---------------------------------------------------------------- 심각도/추정효과

class TestSeverityAndEffect:
    def test_est_effect_computed_from_dong_stats(self):
        """est_effect 수치는 dong_stats에서 계산 — 통계를 바꾸면 문구 수치도 바뀜(하드코딩 금지)."""
        bins = [
            mk_bin("A동", ["스티로폼"], SYN_FLAGS),
            mk_bin("B동", ["무색페트병"], SYN_FLAGS),
        ]
        p1, _ = build_outputs(bins, SYN_MAPPING, syn_stats(**{"A동": (9, 9), "B동": (5678, 1234)}))
        card1 = next(c for c in p1["cards"] if c["item"] == "스티로폼")
        assert "1,234" in card1["est_effect"] and "5,678" in card1["est_effect"]

        p2, _ = build_outputs(bins, SYN_MAPPING, syn_stats(**{"A동": (9, 9), "B동": (8100, 9999)}))
        card2 = next(c for c in p2["cards"] if c["item"] == "스티로폼")
        assert "9,999" in card2["est_effect"] and "8,100" in card2["est_effect"]
        assert card1["est_effect"] != card2["est_effect"]

    def test_est_effect_without_stats_is_qualitative_and_honest(self):
        """통계 없는 동은 정성 문구 + 데이터 부재 명시."""
        bins = [
            mk_bin("A동", ["스티로폼"], SYN_FLAGS),
            mk_bin("무명동", ["무색페트병"], SYN_FLAGS),
        ]
        payload, _ = build_outputs(bins, SYN_MAPPING, syn_stats(**{"A동": (100, 40)}))
        card = next(c for c in payload["cards"] if c["dong"] == "무명동" and c["item"] == "스티로폼")
        assert "미확보" in card["est_effect"] or "데이터 부재" in card["est_effect"]
        assert not any(ch.isdigit() for ch in card["est_effect"].split("—")[0]), (
            "통계 없는 동의 est_effect 앞부분에 근거 없는 수치가 있으면 안 됨"
        )

    def test_higher_population_dong_ranks_first(self):
        """같은 품목 공백이면 인구 큰 동의 카드가 먼저(심각도 점수 내림차순)."""
        bins = [
            mk_bin("소동", ["무색페트병"], SYN_FLAGS),
            mk_bin("대동", ["무색페트병"], SYN_FLAGS),
            mk_bin("공급동", ["스티로폼", "무색페트병"], SYN_FLAGS),
        ]
        payload, _ = build_outputs(
            bins,
            SYN_MAPPING,
            syn_stats(**{"소동": (100, 40), "대동": (50000, 20000), "공급동": (100, 40)}),
        )
        sty = [c for c in payload["cards"] if c["item"] == "스티로폼"]
        assert [c["dong"] for c in sty] == ["대동", "소동"]
        assert sty[0]["severity_score"] > sty[1]["severity_score"]


# ---------------------------------------------------------------- 매핑 단일소스

class TestMappingSingleSource:
    def test_default_mapping_path_is_shared_mapping_json(self):
        assert MAPPING_PATH == REPO_ROOT / "shared" / "mapping.json"
        assert MAPPING_PATH.exists()

    def test_category_id_follows_mapping_file_content(self, tmp_path):
        """mapping.json 내용을 바꾸면 카드 category_id가 따라 바뀜 → 파일을 실제로 읽는다는 증거."""
        bins = load_json(BINS_PATH)
        mapping = load_json(MAPPING_PATH)
        stats = load_json(STATS_PATH)
        mutated = json.loads(json.dumps(mapping))
        for cat in mutated["categories"]:
            if "스티로폼" in cat["csv_flags"]:
                cat["id"] = "styrofoam_MUTATED"
        payload, _ = build_outputs(bins, mutated, stats)
        sty = [c for c in payload["cards"] if c["item"] == "스티로폼"]
        assert sty and all(c["category_id"] == "styrofoam_MUTATED" for c in sty)


# ---------------------------------------------------------------- 실데이터 통합

@pytest.fixture(scope="module")
def real_payload():
    bins = load_json(BINS_PATH)
    mapping = load_json(MAPPING_PATH)
    stats = load_json(STATS_PATH)
    payload, report = build_outputs(bins, mapping, stats)
    return payload, report


class TestRealData:
    def test_at_least_3_policy_cards(self, real_payload):
        payload, _ = real_payload
        assert len(payload["cards"]) >= 3

    def test_styrofoam_card_present_iljik_only(self, real_payload):
        """데모 클라이맥스: 스티로폼 Y거점은 일직동 4곳뿐, 나머지 6개 법정동 0 (실데이터 확인 사실)."""
        payload, _ = real_payload
        sty = [c for c in payload["cards"] if c["item"] == "스티로폼"]
        assert len(sty) == 6  # 7개 법정동 중 일직동 제외 전부 공백
        for c in sty:
            assert c["evidence"]["covered_dongs"] == ["일직동"]
            assert c["evidence"]["bin_counts"]["일직동"] == 4
            assert c["evidence"]["bin_counts"][c["dong"]] == 0

    def test_cooking_oil_is_global_absent_not_card(self, real_payload):
        """식용유: 전 행 Y=0 → 전역 부재. 동별 카드 금지."""
        payload, report = real_payload
        assert "식용유" in payload["global_absent_items"]
        assert all(c["item"] != "식용유" for c in payload["cards"])
        assert "식용유" in report

    def test_unit_is_beopjeong_seven_dongs(self, real_payload):
        payload, _ = real_payload
        assert payload["unit"] == "beopjeong"
        assert sorted(payload["dongs"]) == [
            "가학동", "광명동", "소하동", "옥길동", "일직동", "철산동", "하안동",
        ]

    def test_every_card_est_effect_from_stats_or_flagged(self, real_payload):
        """7개 법정동 전부 통계가 있으므로 모든 카드 est_effect에 세대수 수치가 들어가야 함."""
        payload, _ = real_payload
        stats = load_json(STATS_PATH)["stats"]
        for c in payload["cards"]:
            hh = stats[c["dong"]]["households"]
            assert f"{hh:,}" in c["est_effect"], (
                f"카드({c['dong']}/{c['item']}) est_effect가 dong_stats 세대수와 불일치"
            )

    def test_severity_criteria_documented(self, real_payload):
        payload, report = real_payload
        assert "severity_criteria" in payload
        assert "심각도" in report and "가중치" in report

    def test_committed_policy_cards_up_to_date(self, real_payload):
        """동결 커밋된 data/policy_cards.json이 현재 입력으로 재산출한 결과와 일치(드리프트 금지)."""
        payload, _ = real_payload
        assert CARDS_OUT_PATH.exists(), "data/policy_cards.json 미생성 — build_gaps.py 실행 필요"
        committed = load_json(CARDS_OUT_PATH)
        assert committed == payload

    def test_report_file_exists_with_required_sections(self):
        assert REPORT_OUT_PATH.exists(), "gaps_report.md 미생성 — build_gaps.py 실행 필요"
        text = REPORT_OUT_PATH.read_text(encoding="utf-8")
        for needle in ("심각도", "전역 부재", "식용유", "스티로폼", "법정동"):
            assert needle in text

    def test_snapshot_pinned_and_matches(self, real_payload):
        """첫 실제 산출 결과를 스냅샷으로 pin — 이후 회귀 감지(허구 기대값 금지)."""
        payload, _ = real_payload
        assert SNAPSHOT_PATH.exists(), (
            "스냅샷 미pin 상태 — build_gaps.py 첫 산출 후 data/policy_cards.json을 "
            f"{SNAPSHOT_PATH}로 고정할 것"
        )
        pinned = json.loads(SNAPSHOT_PATH.read_text(encoding="utf-8"))
        assert payload == pinned


# ---------------------------------------------------------------- dong_stats 계약

class TestDongStats:
    def test_seven_dongs_present_with_positive_official_numbers(self):
        stats = load_json(STATS_PATH)
        bins = load_json(BINS_PATH)
        bin_dongs = {r["beopjeong"] for r in bins}
        assert bin_dongs <= set(stats["stats"].keys())
        for dong in bin_dongs:
            entry = stats["stats"][dong]
            assert isinstance(entry["population"], int) and entry["population"] > 0
            assert isinstance(entry["households"], int) and entry["households"] > 0
            assert entry["year"] == "2026.06"
            assert entry["source"].strip()
