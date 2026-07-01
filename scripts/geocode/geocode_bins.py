"""T1 · geocode-pipeline — 광명시 자원순환과 수거함 CSV를 지오코딩해 동결한다.

빌드타임 1회 실행: CSV(헤더 2행, 도로명 259/지번 15, 15품목 플래그)
→ Kakao 지오코딩(주소→좌표) + 역지오코딩(좌표→법정동/행정동)
→ data/bins.geocoded.json 동결. 런타임 지오코딩 금지.
"""
from __future__ import annotations

import csv
import io
import json
import os
import sys
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass

# CSV 컬럼 인덱스 (0-base). 헤더 2행: row0=병합, row1=15플래그명.
_COL_SIGUN, _COL_TYPE, _COL_NAME, _COL_ADDR, _COL_DETAIL, _COL_DAYS = 0, 1, 2, 3, 4, 5
_FLAG_START, _FLAG_END = 6, 21  # cols 6..20 = 15 flags
_COL_DEPT, _COL_PHONE = 21, 22
_HEADER_ROWS = 2


@dataclass
class Bin:
    sigun: str
    type: str
    name: str
    addr: str
    detail: str
    days: str
    items: dict[str, bool]
    dept: str
    phone: str


def _cell(row: list[str], idx: int) -> str:
    return row[idx].strip() if idx < len(row) else ""


def parse_bins_csv(path: str, encoding: str = "cp949") -> list[Bin]:
    """헤더 2행을 건너뛰고 데이터 행을 Bin 리스트로 파싱한다."""
    with open(path, "rb") as f:
        rows = list(csv.reader(io.StringIO(f.read().decode(encoding))))

    flag_names = [c.strip() for c in rows[1][_FLAG_START:_FLAG_END]]

    bins: list[Bin] = []
    for row in rows[_HEADER_ROWS:]:
        if not _cell(row, _COL_ADDR):  # 주소 없는 잡음 행 방어
            continue
        items = {
            name: _cell(row, _FLAG_START + i).upper() == "Y"
            for i, name in enumerate(flag_names)
        }
        bins.append(
            Bin(
                sigun=_cell(row, _COL_SIGUN),
                type=_cell(row, _COL_TYPE),
                name=_cell(row, _COL_NAME),
                addr=_cell(row, _COL_ADDR),
                detail=_cell(row, _COL_DETAIL),
                days=_cell(row, _COL_DAYS),
                items=items,
                dept=_cell(row, _COL_DEPT),
                phone=_cell(row, _COL_PHONE),
            )
        )
    return bins


def geocode_bins(bins: list[Bin], client) -> list[dict]:
    """각 Bin을 지오코딩+역지오코딩해 동결용 record 리스트로.

    같은 주소/좌표는 in-run 캐시로 API 1회만 호출한다.
    실패 행도 전부 포함(geocode_status='failed', 좌표 None).
    """
    coord_cache: dict[str, tuple | None] = {}
    region_cache: dict[tuple, tuple] = {}
    out: list[dict] = []

    for b in bins:
        if b.addr in coord_cache:
            coords = coord_cache[b.addr]
        else:
            try:
                coords = client.geocode(b.addr)
            except Exception:  # 네트워크/쿼터/파싱 실패 → 실패행, 전체 크래시 방지
                coords = None
            coord_cache[b.addr] = coords

        rec = asdict(b)
        if coords is None:
            rec.update(lat=None, lng=None, beopjeong=None, haengjeong=None,
                       geocode_status="failed")
        else:
            lat, lng = coords
            if coords in region_cache:
                beop, haeng = region_cache[coords]
            else:
                try:
                    beop, haeng = client.reverse(lat, lng)
                except Exception:
                    beop, haeng = (None, None)
                region_cache[coords] = (beop, haeng)
            rec.update(lat=lat, lng=lng, beopjeong=beop, haengjeong=haeng,
                       geocode_status="ok")
        out.append(rec)

    return out


# ── Kakao 응답 파서 (네트워크와 분리, 단위 테스트 대상) ──────────────────

def parse_kakao_geocode_response(data: dict) -> tuple | None:
    """Kakao 주소검색 응답 → (lat, lng). 매칭 없으면 None. (x=lng, y=lat)"""
    docs = data.get("documents") or []
    if not docs:
        return None
    d = docs[0]
    try:
        return (float(d["y"]), float(d["x"]))
    except (KeyError, TypeError, ValueError):  # malformed 응답 방어
        return None


def parse_kakao_region_response(data: dict) -> tuple:
    """Kakao coord2regioncode 응답 → (법정동, 행정동). B=법정동, H=행정동."""
    beop = haeng = None
    for d in data.get("documents") or []:
        if d.get("region_type") == "B":
            beop = d.get("region_3depth_name")
        elif d.get("region_type") == "H":
            haeng = d.get("region_3depth_name")
    return (beop, haeng)


class KakaoClient:
    """Kakao Local API 얇은 어댑터. HTTP는 여기, 파싱은 위 함수(테스트됨)."""

    GEOCODE_URL = "https://dapi.kakao.com/v2/local/search/address.json"
    REGION_URL = "https://dapi.kakao.com/v2/local/geo/coord2regioncode.json"

    def __init__(self, api_key: str):
        self.api_key = api_key

    def _get(self, url: str, params: dict) -> dict:
        q = urllib.parse.urlencode(params)
        req = urllib.request.Request(
            f"{url}?{q}", headers={"Authorization": f"KakaoAK {self.api_key}"}
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.load(resp)

    def geocode(self, addr: str):
        return parse_kakao_geocode_response(self._get(self.GEOCODE_URL, {"query": addr}))

    def reverse(self, lat: float, lng: float):
        return parse_kakao_region_response(
            self._get(self.REGION_URL, {"x": lng, "y": lat})
        )


def fill_rates(records: list[dict]) -> dict[str, float]:
    """수용기준 게이트용 채움률(좌표·법정동)."""
    total = len(records) or 1
    has_coords = sum(1 for r in records if r["geocode_status"] in ("ok", "manual"))
    has_beop = sum(1 for r in records if r.get("beopjeong"))
    return {"coords": has_coords / total, "beopjeong": has_beop / total}


def apply_manual_fixes(records: list[dict], fixes: dict[str, tuple]) -> list[dict]:
    """failed 행을 수기 좌표로 보정 → status 'manual'. fixes[addr]=(lat,lng,법정동,행정동)."""
    for r in records:
        if r["geocode_status"] == "failed" and r["addr"] in fixes:
            lat, lng, beop, haeng = fixes[r["addr"]]
            r.update(lat=lat, lng=lng, beopjeong=beop, haengjeong=haeng,
                     geocode_status="manual")
    return records


def passes_gate(rates: dict, coords_min: float = 0.90,
                beop_min: float = 0.95) -> bool:
    """채움률 수용기준 게이트. 미달이면 빌드 실패시켜야 함."""
    return rates["coords"] >= coords_min and rates["beopjeong"] >= beop_min


def run_pipeline(csv_path: str, out_path: str, client,
                 encoding: str = "cp949",
                 manual_fixes: dict | None = None) -> list[dict]:
    """빌드타임 파이프라인. 유효한 동결 파일이 있으면 재실행 시 API 호출 0(멱등).

    없거나 손상/빈 파일이면: CSV 파싱 → 지오코딩 → 수기보정 → out_path에 원자적 동결.
    """
    records = None
    from_cache = False
    if os.path.exists(out_path):
        try:
            with open(out_path, encoding="utf-8") as f:
                cached = json.load(f)
            if cached:  # 비어있지 않은 유효 JSON만 신뢰(0행은 항상 오류)
                records, from_cache = cached, True
        except (json.JSONDecodeError, OSError):
            pass  # 손상 파일 → 재생성

    if records is None:
        bins = parse_bins_csv(csv_path, encoding=encoding)
        records = geocode_bins(bins, client)

    # 수기 보정은 신규/캐시 양쪽에 적용 → 프로즌 파일도 API 0으로 패치 가능
    if manual_fixes:
        records = apply_manual_fixes(records, manual_fixes)

    if not from_cache or manual_fixes:  # 새로 만들었거나 보정했을 때만 재기록
        os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
        tmp = out_path + ".tmp"  # 원자적 쓰기: 크래시 시 손상 파일 잔존 방지
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(records, f, ensure_ascii=False, indent=2)
        os.replace(tmp, out_path)

    return records


# ── CLI: 빌드타임 라이브 실행 (KAKAO_REST_KEY 필요) ─────────────────────
_DEFAULT_CSV = os.path.join(
    os.path.dirname(__file__), "..", "..", "assets", "제공 자료(자원순환과).csv"
)
_DEFAULT_OUT = os.path.join(
    os.path.dirname(__file__), "..", "..", "data", "bins.geocoded.json"
)


def main(argv: list[str] | None = None) -> int:
    key = os.environ.get("KAKAO_REST_KEY")
    if not key:
        print(
            "KAKAO_REST_KEY 미설정 - 라이브 지오코딩 불가.\n"
            "  set KAKAO_REST_KEY=<카카오 REST 키> 후 재실행.\n"
            "  (파이프라인 로직은 목킹 단위 테스트로 이미 검증됨: pytest scripts/geocode/tests)",
            file=sys.stderr,
        )
        return 1
    # 수기 보정: data/manual_fixes.json {주소: [lat,lng,법정동,행정동]} (있으면)
    fixes = {}
    fpath = os.path.join(os.path.dirname(_DEFAULT_OUT), "manual_fixes.json")
    if os.path.exists(fpath):
        with open(fpath, encoding="utf-8") as f:
            fixes = {k: tuple(v) for k, v in json.load(f).items()}

    records = run_pipeline(_DEFAULT_CSV, _DEFAULT_OUT, KakaoClient(key), manual_fixes=fixes)
    rates = fill_rates(records)
    failed = [r for r in records if r["geocode_status"] == "failed"]
    print(f"동결: {_DEFAULT_OUT} ({len(records)}행)")
    print(f"좌표 채움률 {rates['coords']:.1%} · 법정동 채움률 {rates['beopjeong']:.1%}")
    if failed:
        print(f"실패 {len(failed)}행 (data/manual_fixes.json 로 보정 후 재실행):")
        for r in failed:
            print(f"  - {r['addr']}")

    if not passes_gate(rates):
        print("게이트 실패: 채움률 미달(좌표>=90% 법정동>=95%). "
              "manual_fixes.json 보정 후 재실행.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
