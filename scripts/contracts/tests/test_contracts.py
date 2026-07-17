# -*- coding: utf-8 -*-
"""T4 · mapping-single-source — shared/mapping.json + shared/rules.json 계약 테스트.

검증 항목(SPEC T4 Acceptance):
- mapping.json: 8카테고리, 각 csv_flags 비어있지 않음, confidence_threshold == 0.7
- 역매핑 유일성: 각 CSV 플래그는 최대 1개 카테고리에만 등장
- csv_flags 전체가 실제 CSV 15플래그 집합의 부분집합(오탈자 방지)
- rules.json: 키셋 == mapping 카테고리 id 셋, 각 steps 비어있지 않음 + caution 존재
"""
import json
from collections import Counter
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
MAPPING_PATH = REPO_ROOT / "shared" / "mapping.json"
RULES_PATH = REPO_ROOT / "shared" / "rules.json"
FROZEN_PATH = REPO_ROOT / "data" / "bins.geocoded.json"

# SPEC 52행: 건전지·형광등은 유해폐기물 별도 취급 — 앱 인식 8카테고리엔 미포함
HAZARDOUS_EXCLUDED = {"건전지", "형광등"}

# CSV 실제 15플래그 (동결 데이터 data/bins.geocoded.json 의 items 키와 동일 문자열)
CSV_FLAGS_15 = {
    "일반쓰레기",
    "종이",
    "종이팩",
    "금속캔",
    "고철",
    "플라스틱",
    "무색페트병",
    "유리병",
    "비닐",
    "스티로폼",
    "건전지",
    "형광등",
    "소형전자제품",
    "식용유",
    "의류",
}


@pytest.fixture(scope="module")
def mapping():
    with open(MAPPING_PATH, encoding="utf-8") as f:
        return json.load(f)


@pytest.fixture(scope="module")
def rules():
    with open(RULES_PATH, encoding="utf-8") as f:
        return json.load(f)


class TestMapping:
    def test_exactly_8_categories(self, mapping):
        assert len(mapping["categories"]) == 8

    def test_each_category_has_nonempty_csv_flags(self, mapping):
        for cat in mapping["categories"]:
            assert cat["csv_flags"], f"category {cat['id']}: csv_flags 비어 있음"

    def test_confidence_threshold_is_0_7(self, mapping):
        assert mapping["confidence_threshold"] == 0.7

    def test_reverse_mapping_uniqueness(self, mapping):
        """각 CSV 플래그는 최대 1개 카테고리에만 매핑(T6 필터 충돌 방지)."""
        counts = Counter(
            flag for cat in mapping["categories"] for flag in cat["csv_flags"]
        )
        duplicated = {flag: n for flag, n in counts.items() if n > 1}
        assert not duplicated, f"복수 카테고리에 매핑된 플래그: {duplicated}"

    def test_csv_flags_subset_of_actual_15(self, mapping):
        """오탈자 방지: 매핑에 등장하는 모든 플래그가 실제 CSV 15플래그여야 함."""
        used = {flag for cat in mapping["categories"] for flag in cat["csv_flags"]}
        unknown = used - CSV_FLAGS_15
        assert not unknown, f"CSV 15플래그에 없는 문자열: {unknown}"

    def test_flag_union_is_exactly_15_minus_hazardous(self, mapping):
        """완전성: 매핑된 플래그 합집합 == CSV 15플래그 − {건전지, 형광등}.

        SPEC 52행(건전지·형광등 미포함)·54행(식용유는 etc에 유지) 동시 강제:
        (a) 유해폐기물 플래그를 임의 카테고리에 추가하는 회귀,
        (b) 매핑된 플래그(식용유·플라스틱 등)를 조용히 삭제하는 회귀를 모두 차단.
        """
        used = {flag for cat in mapping["categories"] for flag in cat["csv_flags"]}
        expected = CSV_FLAGS_15 - HAZARDOUS_EXCLUDED
        assert used == expected, (
            f"누락된 플래그: {expected - used} / 금지된 플래그: {used - expected}"
        )

    def test_flags_constant_matches_frozen_data(self):
        """테스트 상수 CSV_FLAGS_15가 3번째 사본이 되지 않도록 동결 데이터와 교차검증."""
        with open(FROZEN_PATH, encoding="utf-8") as f:
            records = json.load(f)
        frozen_flags = set()
        for r in records:
            frozen_flags.update(r["items"].keys())
        assert frozen_flags == CSV_FLAGS_15, (
            f"동결 데이터 items 키와 불일치: {frozen_flags ^ CSV_FLAGS_15}"
        )

    def test_each_category_has_nonempty_label(self, mapping):
        """label은 T5 수동선택 그리드·결과 화면에 그대로 노출되는 사용자 문자열."""
        for cat in mapping["categories"]:
            assert cat.get("label", "").strip(), f"category {cat['id']}: label 없음"


class TestRules:
    def test_rules_keys_match_mapping_category_ids(self, mapping, rules):
        mapping_ids = {cat["id"] for cat in mapping["categories"]}
        assert set(rules.keys()) == mapping_ids

    def test_each_rule_has_nonempty_steps(self, rules):
        for cat_id, rule in rules.items():
            assert isinstance(rule["steps"], list) and rule["steps"], (
                f"rules[{cat_id}]: steps 비어 있음"
            )
            assert all(isinstance(s, str) and s.strip() for s in rule["steps"]), (
                f"rules[{cat_id}]: 빈 step 문자열 존재"
            )

    def test_each_rule_has_caution(self, rules):
        for cat_id, rule in rules.items():
            assert rule.get("caution", "").strip(), (
                f"rules[{cat_id}]: caution 없음"
            )

    def test_each_rule_has_source(self, rules):
        """B2G 산출물 — 출처 표기는 신뢰성 핵심. 삭제 회귀 차단."""
        for cat_id, rule in rules.items():
            assert rule.get("source", "").strip(), (
                f"rules[{cat_id}]: source(출처) 없음"
            )

    def test_rule_labels_match_mapping_labels(self, mapping, rules):
        """UI가 mapping.label과 rules.label을 혼용 표시 — 어긋나면 화면 불일치."""
        mapping_labels = {cat["id"]: cat["label"] for cat in mapping["categories"]}
        for cat_id, rule in rules.items():
            assert rule.get("label") == mapping_labels[cat_id], (
                f"rules[{cat_id}].label={rule.get('label')!r} != "
                f"mapping label {mapping_labels[cat_id]!r}"
            )
