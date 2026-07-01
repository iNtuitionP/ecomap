"""T1 · 파이프라인 동결 + 멱등(캐시) 테스트."""
import json
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from geocode_bins import run_pipeline  # noqa: E402

FIXTURE = os.path.join(os.path.dirname(__file__), "fixtures", "sample_bins.csv")

_COORDS = {
    "경기도 광명시 하안동 229": (37.47, 126.88),
    "경기도 광명시 소하동 1383": (37.44, 126.87),
    "경기도 광명시 일직동 505-20": (37.42, 126.89),
    "광명시 광복로 51": (37.48, 126.86),
    "광명시 오리로935번안길 35-2": (37.45, 126.88),
}
_REGIONS = {c: ("하안동", "하안3동") for c in _COORDS.values()}


class FakeClient:
    def __init__(self):
        self.geocode_calls = 0
        self.reverse_calls = 0

    def geocode(self, addr):
        self.geocode_calls += 1
        return _COORDS.get(addr)

    def reverse(self, lat, lng):
        self.reverse_calls += 1
        return _REGIONS.get((lat, lng), (None, None))


def test_freeze_writes_json_with_all_rows(tmp_path):
    out = tmp_path / "bins.geocoded.json"
    recs = run_pipeline(FIXTURE, str(out), FakeClient(), encoding="utf-8")
    assert out.exists()
    assert len(recs) == 5
    saved = json.loads(out.read_text(encoding="utf-8"))
    assert len(saved) == 5
    assert saved[0]["geocode_status"] == "ok"


def test_second_run_makes_zero_api_calls(tmp_path):
    out = tmp_path / "bins.geocoded.json"
    run_pipeline(FIXTURE, str(out), FakeClient(), encoding="utf-8")  # 1차: 동결
    c2 = FakeClient()
    recs = run_pipeline(FIXTURE, str(out), c2, encoding="utf-8")  # 2차: 캐시
    assert c2.geocode_calls == 0
    assert c2.reverse_calls == 0
    assert len(recs) == 5  # 동결 파일에서 로드


def test_corrupt_frozen_file_regenerates(tmp_path):
    out = tmp_path / "b.json"
    out.write_text("{not valid json", encoding="utf-8")  # 손상 파일
    recs = run_pipeline(FIXTURE, str(out), FakeClient(), encoding="utf-8")
    assert len(recs) == 5  # 크래시 대신 재생성


def test_empty_frozen_file_regenerates(tmp_path):
    out = tmp_path / "b.json"
    out.write_text("[]", encoding="utf-8")  # 유효하나 빈
    recs = run_pipeline(FIXTURE, str(out), FakeClient(), encoding="utf-8")
    assert len(recs) == 5  # 0행은 항상 오류 → 재생성


def test_manual_fixes_applied_in_pipeline(tmp_path):
    out = tmp_path / "b.json"

    class Missing(FakeClient):
        def geocode(self, addr):
            self.geocode_calls += 1
            return None if "오리로" in addr else _COORDS.get(addr)

    fixes = {"광명시 오리로935번안길 35-2": (37.45, 126.88, "소하동", "소하2동")}
    recs = run_pipeline(FIXTURE, str(out), Missing(), encoding="utf-8", manual_fixes=fixes)
    target = [r for r in recs if "오리로" in r["addr"]][0]
    assert target["geocode_status"] == "manual"
    assert target["beopjeong"] == "소하동"


def test_manual_fixes_patch_already_frozen_file(tmp_path):
    """실패행을 담은 채 동결된 뒤, 보정을 추가해 재실행하면 API 0으로 패치된다."""
    out = tmp_path / "b.json"

    class Missing(FakeClient):
        def geocode(self, addr):
            self.geocode_calls += 1
            return None if "오리로" in addr else _COORDS.get(addr)

    run_pipeline(FIXTURE, str(out), Missing(), encoding="utf-8")  # 1차: 오리로 failed로 동결
    c2 = Missing()
    fixes = {"광명시 오리로935번안길 35-2": (37.45, 126.88, "소하동", "소하2동")}
    recs = run_pipeline(FIXTURE, str(out), c2, encoding="utf-8", manual_fixes=fixes)  # 2차
    assert c2.geocode_calls == 0  # 캐시 사용(API 0)
    target = [r for r in recs if "오리로" in r["addr"]][0]
    assert target["geocode_status"] == "manual"  # 프로즌 파일이 보정으로 패치됨
