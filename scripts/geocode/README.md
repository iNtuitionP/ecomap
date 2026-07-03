# T1 · geocode-pipeline

광명시 자원순환과 CSV(274행)를 **빌드타임 1회** 지오코딩해 `data/bins.geocoded.json`으로 동결한다. 런타임 지오코딩 금지 — 앱은 동결된 JSON만 읽는다.

> **현재 동결본(2026-07-03, 커밋됨):** 274행 = **270 ok / 4 manual / 0 failed**, 좌표·법정동 채움률 **100%**. Kakao가 못 잡은 3주소는 원본 CSV `detail`의 랜드마크 키워드 검색으로 보정(`data/manual_fixes.json`).

## 파이프라인
```
assets/제공 자료(자원순환과).csv (헤더 2행, 도로명 259/지번 15, 15품목 플래그)
  → parse_bins_csv()      # skiprows=2, CP949
  → Kakao 지오코딩         # 주소 → 좌표 (동일주소 캐시)
  → Kakao 역지오코딩       # 좌표 → 법정동(B)/행정동(H)
  → data/bins.geocoded.json 동결·커밋
```

## 라이브 실행 (키 필요)
```bash
export KAKAO_REST_KEY="<카카오 REST API 키>"   # Windows: set KAKAO_REST_KEY=...
python scripts/geocode/geocode_bins.py
```
- 키 발급: https://developers.kakao.com → 앱 생성 → REST API 키. **카카오맵(OPEN_MAP_AND_LOCAL) 서비스 '활성화 ON' 필수** — 안 하면 403.
- 무료 쿼터: 일 100,000회 (274행엔 충분).
- 출력: 좌표·법정동 채움률 + 실패행 리스트(수기 보정 대상).
- **멱등:** `data/bins.geocoded.json`이 이미 있으면 API 호출 0. 다시 돌리려면 파일 삭제.
- **인증 fail-fast:** 401/403은 `GeocodeConfigError`로 즉시 중단(exit 2, 동결 안 함) — 전 행이 조용히 실패해 오염된 파일이 남는 것 방지.

## 실패행 수기 보정 & 게이트
- 라이브 실행이 **채움률 게이트(좌표≥90% / 법정동≥95%)** 미달이면 **빌드 실패(exit 1)** + 실패행 리스트 출력.
- `data/manual_fixes.json` 에 `{"<주소>": [lat, lng, "법정동", "행정동"]}` 를 넣고 재실행하면 **API 재호출 없이(캐시) 프로즌 파일을 패치**(status→manual). 게이트 통과할 때까지 반복.
- **좌표 sanity 가드:** manual 좌표가 광명시 봉투(lat[37.40,37.51] lng[126.82,126.90], 270개 검증 ok행 실측+여유) 밖이면 **`ValueError`로 빌드 중단**. lat/lng 뒤바뀜·인접 시(안양 석수동 등) 오매칭 방어 — 채움률 게이트가 못 거르는 "그럴듯하지만 틀린" manual 좌표를 잡는다.
- **보정 팁:** 주소검색이 실패하면 원본 CSV `detail`(랜드마크: "○○공원", "○○복지회관")을 키워드 검색하면 잘 잡힌다. 단, 퍼지 매칭이 다른 시(市)를 잡을 수 있으니 반드시 역지오코딩으로 광명시인지 교차검증할 것.
- **원자적 쓰기**(tmp→os.replace) + 손상/빈 동결 파일 자동 재생성. 네트워크/malformed 응답은 **해당 행만 failed**(전체 크래시 없음).

## 참고: dedup
API 호출은 주소 문자열 캐시로 dedup(중복 274주소 중 유니크 ~170). **출력 JSON은 물리적 수거함 개체를 보존**(동일 좌표 여러 행 유지) — 수거함은 실재하므로 의도된 것. 동 단위 집계(T3)는 개체 수가 아니라 Y/N 커버리지로 계산.

## 테스트 (키 불필요, Kakao 목킹)
```bash
python -m pytest scripts/geocode/tests -q
```
31개: 파싱(2행헤더·15플래그·실CSV 274행) / 지오코딩(ok·failed·캐시) / 동결·멱등 / 채움률·수기보정·봉투가드 / Kakao 응답 파서 / 인증 fail-fast(401/403).

## 수용기준 매핑 (SPEC T1)
| 기준 | 커버 |
|---|---|
| 274행 전부 포함 | `test_real_csv_parses_all_274_rows` + `run_pipeline` |
| geocode_status ok/manual/failed | `test_geocode_*`, `test_apply_manual_fixes_*` |
| 좌표·법정동 채움률 | `fill_rates()` + CLI 리포트 |
| 재실행 API 호출 0 (멱등) | `test_second_run_makes_zero_api_calls` |
| 동일주소 dedup | `test_same_address_geocoded_only_once` |
| 실패행 분리 | CLI 실패 리스트 + `apply_manual_fixes` |
| manual 좌표 봉투 검증 | `test_manual_fix_with_swapped_latlng_raises`, `test_manual_fix_outside_gwangmyeong_raises` |
| 인증 오류 fail-fast | `test_config_error_propagates_not_swallowed` |
