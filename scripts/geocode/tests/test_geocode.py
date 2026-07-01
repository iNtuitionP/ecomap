"""T1 · 지오코딩(주입 클라이언트, Kakao 목킹) 테스트."""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from geocode_bins import Bin, geocode_bins  # noqa: E402


class FakeClient:
    """Kakao 대역. 호출 횟수를 세어 캐시/멱등을 검증한다."""

    def __init__(self, coords_by_addr, region_by_coord):
        self.coords_by_addr = coords_by_addr
        self.region_by_coord = region_by_coord
        self.geocode_calls = 0
        self.reverse_calls = 0

    def geocode(self, addr):
        self.geocode_calls += 1
        return self.coords_by_addr.get(addr)  # (lat, lng) | None

    def reverse(self, lat, lng):
        self.reverse_calls += 1
        return self.region_by_coord.get((lat, lng), (None, None))  # (법정동, 행정동)


def _bin(addr):
    return Bin("광명시", "재활용품 분리배출함", "수거대", addr, "", "상시", {}, "자원순환과", "02")


def test_geocode_ok_sets_coords_and_dong_and_status():
    client = FakeClient(
        {"경기도 광명시 하안동 229": (37.47, 126.88)},
        {(37.47, 126.88): ("하안동", "하안3동")},
    )
    out = geocode_bins([_bin("경기도 광명시 하안동 229")], client)
    r = out[0]
    assert r["lat"] == 37.47 and r["lng"] == 126.88
    assert r["beopjeong"] == "하안동"
    assert r["haengjeong"] == "하안3동"
    assert r["geocode_status"] == "ok"


def test_geocode_failure_sets_status_failed_and_null_coords():
    client = FakeClient({}, {})  # 주소 매칭 실패
    out = geocode_bins([_bin("알 수 없는 주소")], client)
    r = out[0]
    assert r["geocode_status"] == "failed"
    assert r["lat"] is None and r["lng"] is None
    assert r["beopjeong"] is None


def test_same_address_geocoded_only_once():
    client = FakeClient(
        {"경기도 광명시 하안동 229": (37.47, 126.88)},
        {(37.47, 126.88): ("하안동", "하안3동")},
    )
    geocode_bins([_bin("경기도 광명시 하안동 229"), _bin("경기도 광명시 하안동 229")], client)
    assert client.geocode_calls == 1  # 동일 주소 캐시


def test_all_input_rows_present_in_output():
    client = FakeClient({"a": (1.0, 2.0)}, {(1.0, 2.0): ("하안동", "하안3동")})
    out = geocode_bins([_bin("a"), _bin("b"), _bin("c")], client)
    assert len(out) == 3  # 실패해도 전부 포함
    assert out[0]["items"] == {}  # Bin 필드 보존
    assert out[0]["dept"] == "자원순환과"


def test_client_exception_marks_row_failed_not_crash():
    class Raising:
        def geocode(self, addr):
            if addr == "boom":
                raise RuntimeError("api down")
            return (1.0, 2.0)

        def reverse(self, lat, lng):
            return ("하안동", "하안3동")

    out = geocode_bins([_bin("ok"), _bin("boom")], Raising())
    assert out[0]["geocode_status"] == "ok"
    assert out[1]["geocode_status"] == "failed"  # 예외 = 실패행, 전체 크래시 아님


def test_reverse_none_keeps_ok_status_with_null_beopjeong():
    client = FakeClient({"a": (1.0, 2.0)}, {})  # reverse → (None, None)
    out = geocode_bins([_bin("a")], client)
    assert out[0]["geocode_status"] == "ok"      # 좌표는 있음
    assert out[0]["beopjeong"] is None           # 계약 고정
