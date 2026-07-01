"""T1 · 채움률 리포트 + 수기 보정(manual) + 실CSV 274행 수용기준."""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from geocode_bins import apply_manual_fixes, fill_rates, parse_bins_csv  # noqa: E402

REAL_CSV = os.path.join(
    os.path.dirname(__file__), "..", "..", "..", "assets", "제공 자료(자원순환과).csv"
)


def _rec(addr, status, beop=None):
    return {"addr": addr, "geocode_status": status, "lat": None, "lng": None,
            "beopjeong": beop, "haengjeong": None}


def test_fill_rates_computes_coord_and_beopjeong_fractions():
    recs = [
        {"geocode_status": "ok", "beopjeong": "하안동"},
        {"geocode_status": "ok", "beopjeong": "소하동"},
        {"geocode_status": "ok", "beopjeong": None},   # 좌표는 있으나 역지오코딩 실패
        {"geocode_status": "failed", "beopjeong": None},
    ]
    rates = fill_rates(recs)
    assert rates["coords"] == 0.75          # 4개 중 3개 ok
    assert rates["beopjeong"] == 0.5        # 4개 중 2개 beopjeong 채워짐


def test_apply_manual_fixes_upgrades_failed_to_manual():
    recs = [_rec("알 수 없는 주소", "failed"), _rec("경기도 광명시 하안동 229", "ok", "하안동")]
    fixes = {"알 수 없는 주소": (37.47, 126.88, "하안동", "하안3동")}
    out = apply_manual_fixes(recs, fixes)
    assert out[0]["geocode_status"] == "manual"
    assert out[0]["lat"] == 37.47 and out[0]["beopjeong"] == "하안동"
    assert out[1]["geocode_status"] == "ok"  # 이미 ok인 건 안 건드림


def test_manual_fix_ignores_addresses_not_failed():
    recs = [_rec("경기도 광명시 하안동 229", "ok", "하안동")]
    out = apply_manual_fixes(recs, {"경기도 광명시 하안동 229": (0, 0, "x", "y")})
    assert out[0]["geocode_status"] == "ok"  # failed 아니면 무시


def test_real_csv_parses_all_274_rows():
    bins = parse_bins_csv(REAL_CSV)  # 기본 encoding=cp949
    assert len(bins) == 274
    assert all(len(b.items) == 15 for b in bins)
    assert bins[0].dept == "자원순환과"


def test_passes_gate_enforces_thresholds():
    from geocode_bins import passes_gate
    assert passes_gate({"coords": 0.95, "beopjeong": 0.96}) is True
    assert passes_gate({"coords": 0.80, "beopjeong": 0.99}) is False   # coords 미달
    assert passes_gate({"coords": 0.95, "beopjeong": 0.90}) is False   # beopjeong 미달
