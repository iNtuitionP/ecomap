# T1 · geocode-pipeline

광명시 자원순환과 CSV(274행)를 **빌드타임 1회** 지오코딩해 `data/bins.geocoded.json`으로 동결한다. 런타임 지오코딩 금지 — 앱은 동결된 JSON만 읽는다.

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
- 키 발급: https://developers.kakao.com → 앱 생성 → REST API 키. Local API 활성화.
- 무료 쿼터: 일 100,000회 (274행엔 충분).
- 출력: 좌표·법정동 채움률 + 실패행 리스트(수기 보정 대상).
- **멱등:** `data/bins.geocoded.json`이 이미 있으면 API 호출 0. 다시 돌리려면 파일 삭제.

## 실패행 수기 보정 & 게이트
- 라이브 실행이 **채움률 게이트(좌표≥90% / 법정동≥95%)** 미달이면 **빌드 실패(exit 1)** + 실패행 리스트 출력.
- `data/manual_fixes.json` 에 `{"<주소>": [lat, lng, "법정동", "행정동"]}` 를 넣고 재실행하면 **API 재호출 없이(캐시) 프로즌 파일을 패치**(status→manual). 게이트 통과할 때까지 반복.
- **원자적 쓰기**(tmp→os.replace) + 손상/빈 동결 파일 자동 재생성. 네트워크/malformed 응답은 **해당 행만 failed**(전체 크래시 없음).

## 참고: dedup
API 호출은 주소 문자열 캐시로 dedup(중복 274주소 중 유니크 ~170). **출력 JSON은 물리적 수거함 개체를 보존**(동일 좌표 여러 행 유지) — 수거함은 실재하므로 의도된 것. 동 단위 집계(T3)는 개체 수가 아니라 Y/N 커버리지로 계산.

## 테스트 (키 불필요, Kakao 목킹)
```bash
python -m pytest scripts/geocode/tests -q
```
18개: 파싱(2행헤더·15플래그·실CSV 274행) / 지오코딩(ok·failed·캐시) / 동결·멱등 / 채움률·수기보정 / Kakao 응답 파서.

## 수용기준 매핑 (SPEC T1)
| 기준 | 커버 |
|---|---|
| 274행 전부 포함 | `test_real_csv_parses_all_274_rows` + `run_pipeline` |
| geocode_status ok/manual/failed | `test_geocode_*`, `test_apply_manual_fixes_*` |
| 좌표·법정동 채움률 | `fill_rates()` + CLI 리포트 |
| 재실행 API 호출 0 (멱등) | `test_second_run_makes_zero_api_calls` |
| 동일주소 dedup | `test_same_address_geocoded_only_once` |
| 실패행 분리 | CLI 실패 리스트 + `apply_manual_fixes` |
