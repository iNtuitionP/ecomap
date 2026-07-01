"""T1 geocode-pipeline — CSV 파싱 테스트."""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from geocode_bins import parse_bins_csv  # noqa: E402

FIXTURE = os.path.join(os.path.dirname(__file__), "fixtures", "sample_bins.csv")


def test_skips_two_header_rows_and_returns_data_rows():
    bins = parse_bins_csv(FIXTURE, encoding="utf-8")
    # 픽스처는 헤더 2행 + 데이터 5행
    assert len(bins) == 5


def test_parses_core_fields():
    bins = parse_bins_csv(FIXTURE, encoding="utf-8")
    first = bins[0]
    assert first.addr == "경기도 광명시 하안동 229"
    assert first.type == "재활용품 분리배출함"
    assert first.dept == "자원순환과"
    assert first.phone == "02-2680-2836"


def test_parses_item_flags_as_bool_by_name():
    bins = parse_bins_csv(FIXTURE, encoding="utf-8")
    first = bins[0]  # 무색페트병=Y, 비닐=Y, 나머지 빈칸
    assert first.items["무색페트병"] is True
    assert first.items["비닐"] is True
    assert first.items["스티로폼"] is False
    # 15개 플래그 전부 존재
    assert len(first.items) == 15


def test_iljik_dong_has_styrofoam():
    bins = parse_bins_csv(FIXTURE, encoding="utf-8")
    iljik = [b for b in bins if "일직동" in b.addr][0]
    assert iljik.items["스티로폼"] is True
