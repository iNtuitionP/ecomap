"""T1 · Kakao API 응답 파서 테스트 (네트워크 없이 응답 shape만)."""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from geocode_bins import (  # noqa: E402
    parse_kakao_geocode_response,
    parse_kakao_region_response,
)


def test_geocode_response_returns_lat_lng_floats():
    data = {"documents": [{"x": "126.8845", "y": "37.4772"}], "meta": {"total_count": 1}}
    assert parse_kakao_geocode_response(data) == (37.4772, 126.8845)  # (lat=y, lng=x)


def test_geocode_no_match_returns_none():
    data = {"documents": [], "meta": {"total_count": 0}}
    assert parse_kakao_geocode_response(data) is None


def test_region_response_extracts_beopjeong_and_haengjeong():
    data = {"documents": [
        {"region_type": "B", "region_3depth_name": "하안동"},   # 법정동
        {"region_type": "H", "region_3depth_name": "하안3동"},  # 행정동
    ]}
    assert parse_kakao_region_response(data) == ("하안동", "하안3동")


def test_region_response_beopjeong_only():
    data = {"documents": [{"region_type": "B", "region_3depth_name": "일직동"}]}
    assert parse_kakao_region_response(data) == ("일직동", None)


def test_geocode_response_malformed_missing_xy_returns_none():
    data = {"documents": [{"road_address": "x"}]}  # documents는 있으나 x/y 없음
    assert parse_kakao_geocode_response(data) is None


def test_geocode_response_nonnumeric_xy_returns_none():
    data = {"documents": [{"x": "", "y": "N/A"}]}
    assert parse_kakao_geocode_response(data) is None
