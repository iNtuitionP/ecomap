# SPEC — 에코지도 찌릿 (7월 프로토타입, 구현 명세)

> 이 문서는 승인된 설계(`office-hours → plan-eng-review → CEO → design` 통과)를 **구현 가능한 명세**로 굳힌 것이다. 재설계가 아니라 실행 명세다. 원본 설계/근거: `~/.gstack/projects/iNtuitionP-ecomap/parkj-main-design-20260627-134321.md`. 디자인 15화면 목업: `designs/demo-flow-*.png`, `designs/rest-screens-*.png`.

## Context

광명시 청년 공모사업 앱. 고객 = **광명시 자원순환과(B2G)**, 데이터 생성원 = 광명시 시민. 7월 프로토타입 데모(5분 매직 모먼트)가 목표. 학생 3인, 4~10월.

핵심 서사: 사진 → 품목 카테고리 인식(AI) → 룰베이스 분리배출 가이드 → 실데이터 최근접 수거함 → **시(市) 공백분석 정책카드(데모 클라이맥스)**. "AI는 뭔지, 룰은 어떻게." 바코드는 강등(한국에 공개 바코드→재질 DB 없음).

## Current State

**그린필드. 코드 0.** 존재하는 것: `README.md`, `UIUX.png`, `assets/제공 자료(자원순환과).csv`(274행), `designs/*.png`(15화면 목업), `.github/workflows/{ci,release}.yml`, `TODOS.md`. Flutter/FastAPI 프로젝트 미생성.

> ⚠️ **README·UIUX.png는 구(舊) 바코드 설계다. 이 SPEC이 정본**(이미지 인식 전환 반영). 신입은 SPEC 먼저 읽을 것.
>
> ⚠️ **CSV 구조 주의(실측):** 데이터 274행이지만 **헤더가 2행**(row0 병합 `배출품목`, row1 실제 15플래그) → 파싱 시 `skiprows=1`. 주소는 **도로명 259행 / 지번 15행**(94.5% 도로명) → 문자열로 법정동 파싱 불가, T1 역지오코딩 필수. 컬럼 21~22 = 담당부서·전화(02-2680-2836).

## Architecture (확정 — 변경 금지)

- **7월 데모 = 정적 precompute.** 라이브 백엔드 0. 지도·공백분석·최근접을 빌드타임 JSON으로 앱에 동봉. 274행 최근접은 **클라이언트 distance sort**(PostGIS 데모엔 불필요).
- **FastAPI/PostGIS = 8월** RECOG_EVENTS 실로깅 시작 시(범위는 TODOS T-1 보류).
- **멀티모달 API 키:** 데모는 앱 임베드(통제·데모 후 로테이트) → **8월 프록시 뒤로.** 실사용자 배포 APK에 키 노출 금지.
- 스택: Flutter + Riverpod, 지도 Kakao(잠정 락인), 멀티모달 API. 배포 = APK GitHub Releases(기존 CI/CD).

## Scope

**In (7월 데모):** T1~T10.
**Out(→TODOS):** 8월 FastAPI 척추 실범위, 포인트/랭킹 전면, 실보상 연계(기후행동 기회소득), 전국 바코드 DB, 자체 ML 학습, 행정동 top-up.

---

## Shared Contracts (데이터 단일 소스)

### `shared/mapping.json` — 인식 8카테고리 ↔ CSV 15플래그 (T4)
앱과 빌드 스크립트가 **공유**하는 단일 소스. 양쪽에 중복 금지.
```json
{
  "categories": [
    { "id": "pet",       "label": "무색 페트병", "csv_flags": ["무색페트병"] },
    { "id": "can",       "label": "캔/고철",     "csv_flags": ["금속캔", "고철"] },
    { "id": "paper",     "label": "종이",         "csv_flags": ["종이"] },
    { "id": "vinyl",     "label": "비닐",         "csv_flags": ["비닐"] },
    { "id": "glass",     "label": "유리병",       "csv_flags": ["유리병"] },
    { "id": "styrofoam", "label": "스티로폼",     "csv_flags": ["스티로폼"] },
    { "id": "papercup",  "label": "종이팩",       "csv_flags": ["종이팩"] },
    { "id": "etc",       "label": "기타",         "csv_flags": ["소형전자제품", "식용유", "의류", "일반쓰레기", "플라스틱"] }
  ],
  "confidence_threshold": 0.7
}
```
> CSV 실제 15플래그: 일반쓰레기·종이·종이팩·금속캔·고철·플라스틱·무색페트병·유리병·비닐·스티로폼·건전지·형광등·소형전자제품·식용유·의류. (건전지·형광등은 유해폐기물 별도 취급, 앱 인식 8카테고리엔 미포함 — 어드민 분석에는 포함.)
>
> **역매핑 유일성(중요):** 각 CSV 플래그는 정확히 1개 카테고리에만 매핑(종이팩=papercup 전용, paper=종이만). 겹치면 T6의 카테고리→거점 필터가 충돌. **식용유는 CSV Y=0행(죽은 매핑)** — etc에 두되 최근접·eval 표본에선 실질 무효로 처리. 무색페트병(pet)과 일반 플라스틱(etc)은 분리: "일반 플라스틱" 스캔 시 etc→플라스틱 거점, "페트병" 스캔 시 pet→무색페트병 거점(의도된 분기).

### `shared/rules.json` — 카테고리 → 배출 단계 (T4)
```json
{
  "pet": { "steps": ["라벨 떼기", "내용물 비우고 헹구기", "찌그러뜨려 압착", "무색 페트병 전용함"], "caution": "뚜껑은 재질이 달라 따로 분리" },
  "can": { "steps": ["내용물 비우기", "가능하면 압착", "금속캔함"], "caution": "부탄가스는 구멍 뚫어 배출" }
  // ... 8카테고리 전부. 출처: 환경부/광명시 분리배출 가이드 인용
}
```

### `data/bins.geocoded.json` — 지오코딩 동결 산출물 (T1)
```json
[
  {
    "id": 1, "type": "재활용품 분리배출함", "name": "수거대",
    "addr": "경기도 광명시 하안동 229", "detail": "",
    "lat": 37.4772, "lng": 126.8845,
    "beopjeong": "하안동", "haengjeong": "하안3동",
    "items": { "무색페트병": true, "비닐": true, "스티로폼": false, "...": "..." },
    "geocode_status": "ok",     // ok | manual | failed
    "dept": "자원순환과", "phone": "02-2680-2836"
  }
]
```

### DB 스키마 (앱 로컬 SQLite; 8월 FastAPI/PostGIS 이관) (T7)
```
RECOG_EVENTS(
  id INTEGER PK, ts TEXT, lat REAL, lng REAL, dong TEXT,
  category TEXT,        -- 8카테고리 id
  csv_flag TEXT,        -- 매핑된 CSV 플래그
  confidence REAL, manual_fallback INTEGER,  -- 0/1
  install_id TEXT,      -- 앱 첫 실행 시 생성한 익명 UUID
  session_id TEXT
)
POINT_LOGS( id INTEGER PK, install_id TEXT, points INTEGER, reason TEXT, ts TEXT )
-- 데모: RECOG_EVENTS는 로컬/시드. POINT_LOGS는 테이블만 생성, 적립 로직·UI는 측정 게이트 후.
```

---

## Child Tasks (T1~T10)

각 태스크: **What / Files / Acceptance Criteria(pass·fail) / Test.** 우선순위 P1=데모 필수, P2=같은 데모 사이클.

### T1 · geocode-pipeline (P1) — 데이터 척추 선결 · **단일 실패점**
**⚠️ T3·T6·T8이 전부 이 산출물에 의존.** 미끄러지면 데모 클라이맥스가 통째로 날아감. 전담 1인, 4월 1주차 착수. 견적 상향: **3-4d**(학생 첫 지오코딩 기준).
**What:** CSV(274행, 좌표0, **도로명 259 / 지번 15**)를 **빌드타임 1회** Kakao 지오코딩 → 좌표 + **역지오코딩으로 법정동/행정동**(문자열 파싱 아님) → `data/bins.geocoded.json` 동결·커밋. 런타임 금지. 동일좌표 중복(예: 일직동 505-20 2회) dedup.
**Files:** `scripts/geocode/geocode_bins.py`, `data/bins.geocoded.json`, `scripts/geocode/README.md`(Kakao 키 사용법·쿼터).
**Acceptance:**
1. `bins.geocoded.json`이 274행 전부 포함(`geocode_status`: ok|manual|failed).
2. 좌표 채움률 ≥ 90%(재활용품 분리배출함·무인회수기 100% 목표).
3. **`beopjeong` 채움률 ≥ 95%** (역지오코딩). 도로명 실패 행은 지번 폴백 + 수기 보정. `haengjeong`은 T2 게이트 통과 시.
4. 동결 파일 있으면 재실행 시 **API 호출 0**(멱등·캐시).
5. 실패 행 `failed` 분리 + 수기 보정 리스트 출력.
6. **최소 보장선:** 최악(역지오코딩 대량 실패)에도 **일직동 지번 4행(스티로폼 Y)** 으로 T3 스티로폼 카드 1건은 확실히 산출.
**Test:** 픽스처(지번3+도로명2) → 좌표·법정동 채워짐 스냅샷. 재실행 API 호출 0 단위 테스트. `beopjeong` 채움률 리포트.

### T2 · geocode-verify (P1) — 4월 1주차 게이트
**What:** 지오코딩 매칭률 + 행정동 역지오코딩 20샘플 **수기 대조**. 통과 시 행정동(18) 채택, 실패 시 법정동(8) 확정.
**Files:** `scripts/geocode/verify_report.md`.
**Acceptance:**
1. 274행 중 좌표 실패율 리포트 산출.
2. 무작위 20행의 행정동 값을 지도 육안 대조, 정확도 기록.
3. 행정동 정확도 <80%면 공백분석 단위를 **법정동 8**로 확정(문서 반영).
**Test:** 수동 검증(자동화 아님). 리포트 파일 존재로 완료.

### T3 · gap-analysis (P1) — 데모 클라이맥스 데이터
**What:** `bins.geocoded.json`의 **`beopjeong` 필드**(T1 역지오코딩 산출물, 문자열 파싱 아님)로 **「법정동 × 품목」 매트릭스** → Y거점 0셀 = 정책 후보 → `data/policy_cards.json`.
**Files:** `scripts/gap_analysis/build_gaps.py`, `data/policy_cards.json`, `scripts/gap_analysis/gaps_report.md`.
**Acceptance:**
1. 정책 후보 **최소 3건** 산출. **구체 문구·개수는 build_gaps.py 산출 후 확정**(스펙에 숫자 하드코딩 금지 — 산출 전엔 "스티로폼은 일직동에만, 나머지 법정동 0개"만 확실). 옥길동·가학동 카드는 산출 결과로 채택 여부 결정.
2. 각 카드에 `dong, item, action, est_effect`. `est_effect`(추정 효과)는 **동 인구/세대수 공개데이터 × 커버 반경 계산식**으로 산출(수기 금지). 데이터 없으면 정성 문구로 명시.
3. 트래픽 0(RECOG_EVENTS 없음)에서도 산출됨.
**Test:** build_gaps.py **산출 결과를 스냅샷으로 pin**(첫 산출 후 고정 — 허구 기대값 금지). `beopjeong` 필드 소비 검증. **문자열 파싱 유틸 테스트 없음**(파싱 안 함).

### T4 · mapping-single-source (P1)
**What:** `shared/mapping.json` + `shared/rules.json`을 단일 소스로. 앱·빌드 스크립트가 모두 이 파일을 읽음.
**Files:** `shared/mapping.json`, `shared/rules.json`, `app/lib/shared/mapping_loader.dart`.
**Acceptance:**
1. 8카테고리 각각 CSV 플래그로 매핑됨(위 계약대로).
2. 8카테고리 각각 rules.json에 배출 단계 有(빈 값 없음).
3. 앱과 스크립트가 **같은 파일**을 참조(중복 정의 0 — grep으로 확인).
**Test:** 매핑 완전성 단위 테스트(8카테고리 전부 flags·steps 존재).

### T5 · recognition-flow (P1) — 인식 히어로 · **API 키 blocking**
**⚠️ 멀티모달 API 키 확보가 blocking dependency** — 키 없으면 착수 불가(병렬 시작 아님).
**What:** 카메라 → **Claude 비전(최신 Sonnet/Opus) 1콜** → 8카테고리 + confidence(구조화 출력 강제). `conf ≥ 0.7` → 결과 화면(카테고리·가이드). `conf < 0.7` → 수동 선택 fallback(8품목 그리드). 제품명·브랜드 표시 안 함.
**Files:** `app/lib/recognition/{camera_screen,result_screen,manual_select_screen,recognition_service}.dart`.
**디자인:** `designs/demo-flow-*.png` ①스캔 ②인식결과, `designs/new-screens-*` ③fallback.
**Acceptance:**
1. 사진 촬영 → 8카테고리 중 하나 + confidence 반환.
2. `conf ≥ 0.7`: 결과 화면에 카테고리 배지 + 가이드 미리보기 + "수거함 찾기". **제품명/브랜드 UI 없음.**
3. `conf < 0.7`: 수동 선택 화면(8그리드), 선택 시 결과 화면으로. `manual_fallback=true` 로깅.
4. API 타임아웃/에러 → 수동 선택으로 graceful(크래시·빈화면 금지).
5. 카메라 권한 거부 → 수동 선택 경로 안내.
**Test:** [→E2E] 사전검증 품목 스캔→가이드. [→E2E] 저신뢰도→수동선택. 타임아웃 목킹→fallback 단위 테스트.

### T6 · nearest-empty-edge (P1) — [CRITICAL 엣지]
**What:** 인식 카테고리 → CSV 플래그 → **그 품목 받는 최근접 거점만** 클라이언트 distance sort. **빈 결과**(품목 거점 0개) → graceful UX.
**Files:** `app/lib/map/{nearest_service,map_screen,empty_state_screen}.dart`.
**디자인:** `designs/demo-flow-*` ④지도, ⑤빈상태.
**Acceptance:**
1. 해당 품목 Y인 거점만 필터 → 거리순 정렬 → 최근접 N개 핀+리스트.
2. **거점 0개**(예: 옥길동 스티로폼): 크래시/빈화면 금지 → "근처 없음 + 가장 가까운 OO동 + 이 사각지대를 광명시에 알리기" 화면.
3. distance sort는 274행에서 < 50ms.
**Test:** [CRITICAL] 빈 결과 위젯 테스트(0개 거점 → 안내 화면 렌더). 최근접 정렬 단위 테스트.

### T7 · recog-events (P2)
**What:** `RECOG_EVENTS`(익명 install-id) + `POINT_LOGS` 스키마. 데모 = 로컬 SQLite/시드. install-id는 앱 첫 실행 시 UUID 생성·로컬 저장.
**Files:** `app/lib/events/{db,event_logger,install_id}.dart`.
**Acceptance:**
1. 앱 첫 실행 시 UUID 생성·영속 저장, 모든 RECOG_EVENTS에 첨부.
2. 인식/수동선택 1건마다 이벤트 적재(위 스키마).
3. POINT_LOGS 테이블 생성만(적립 로직·UI 없음).
**Test:** install-id 재실행 시 동일값 단위 테스트. 이벤트 스키마 적재 테스트.

### T8 · admin-policy-cards (P2) — 데모 클라이맥스 화면
**What:** 어드민 공백분석 화면. `policy_cards.json` 로드 → Top3 정책카드 + 히트맵(보조, 시드). 각 카드에 행정 액션+추정 효과.
**Files:** `app/lib/admin/{admin_screen,policy_card}.dart`.
**디자인:** `designs/demo-flow-*` ⑥어드민.
**Acceptance:**
1. 정책카드 3건 표시(T3 산출), 각 심각도 칩 + 행정 액션 + 추정 효과.
2. "시민 데이터·트래픽 0에서도 산출" 카피.
3. 히트맵은 시드 데이터임을 정직 라벨링.
**Test:** policy_cards.json → 카드 3건 렌더 위젯 테스트.

### T9 · multimodal-eval (P2)
**What:** 멀티모달 8카테고리 분류 품질 eval + 임계값 0.7 튜닝.
**Files:** `eval/recognition/{cases,run_eval}.md`.
**Acceptance:**
1. 데모 품목 + 흔한 품목(8카테고리 대표) 테스트셋 ≥ 24건.
2. 카테고리 정확도 리포트 + 임계값별 fallback률.
3. 오분류 케이스 목록.
**Test:** eval 실행 리포트 존재.

### T10 · demo-script (P2)
**What:** 5분 데모 각본. 사전검증 품목 3~4개 + 저신뢰도 fallback 시연 1개 + 녹화 백업.
**Files:** `docs/demo-script.md`, `docs/demo-fallback.mp4`(녹화).
**Acceptance:**
1. 각본: 스캔→인식→가이드→최근접→**어드민 정책카드 클라이맥스** 순서, 대사·화면 명시.
2. 사전검증 품목 리스트(인식 확실한 것) + 1개 fallback 시연.
3. 네트워크 실패 대비 녹화 영상 준비.
**Test:** 리허설 1회 완주(수동).

---

## Dependency Graph & Sequencing

```
T1 지오코딩 ─┬─> T3 공백분석 ──> T8 어드민 화면
             ├─> T6 최근접(좌표 사용)
T2 검증게이트 ┘   (T1 직후, 4월 1주차)

T4 매핑 단일소스 ──> T5 인식 플로우 ──> T6 최근접 ──> T7 이벤트로깅
                                    └─> T9 eval

T10 데모각본 (T5·T8 완료 후 마지막)
```
**Lane A(데이터):** T1→T2→T3 (scripts/, data/) 순차.
**Lane B(계약):** T4 (shared/) 독립 — 먼저, 앱을 블록.
**Lane C(앱):** T5→T6→T7 (app/) 순차, T4+T1 의존.
**실행:** T1 + T4 병렬 시작 → T4 후 C 착수(**단 C=T5는 멀티모달 API 키 확보가 blocking — 키 먼저**), T1 후 A(T3) → T8. C 레인 내부는 app/ 공유라 순차.

## Testing Pyramid

| Layer | What | Count |
|---|---|---|
| Unit | 동 파싱, 매핑 완전성, 최근접 정렬, install-id, confidence 분기 | +8 |
| Integration | 지오코딩 멱등, 공백분석 스냅샷(정책카드 3건) | +3 |
| E2E | 스캔→인식→가이드→최근접 / 저신뢰도→수동선택 | +2 |
| Eval | 멀티모달 8카테고리 분류 품질 | +1 |
| **CRITICAL** | 빈 최근접 결과 graceful(크래시 금지) | +1 |

## Effort Estimate (human 기준, 학생 3인)

| 태스크 | 사람 | 비고 |
|---|---|---|
| T1 geocode | 2-3d | 단일 실패점, 전담 1인 |
| T2 verify | 0.5d | 수동 |
| T3 gap-analysis | 1d | 좌표 불필요, 가장 쉬움 |
| T4 mapping | 0.5d | |
| T5 recognition | 2-3d | 멀티모달 통합 |
| T6 nearest+empty | 1d | |
| T7 events | 1d | |
| T8 admin | 1-2d | |
| T9 eval | 0.5d | |
| T10 demo | 0.5d | |

## Rollback

그린필드라 롤백 리스크 낮음. 데이터 파이프(T1·T3) 산출물은 **동결 커밋**이라 재생성 없이 revert 가능. 앱은 기능 플래그 없이 화면 단위 독립.

## Out of Scope (→ TODOS.md)

8월 FastAPI 척추 실범위(T-1) · 실보상 연계(T-2) · 행정동 top-up(T-3) · 포인트/랭킹 전면(T-4) · 바코드 전국 DB · 자체 ML.

## Decisions (확정 · 2026-07)

1. **지도/지오코딩 SDK = Kakao** ✅ — Kakao Local(주소→좌표) + 역지오코딩(좌표→법정동·행정동) + 지도 SDK. T1이 이걸 상대로 붙음.
2. **이미지 인식 = Claude 비전(최신 Sonnet/Opus)** ✅ — 카테고리+confidence 구조화 출력. T5가 이걸 상대로 붙음.

## Open (남은 것)

- **멀티모달 API 키 확보** — **T5의 blocking dependency**(키 먼저, 병렬 시작 아님). 데모는 앱 임베드(통제·로테이트), 8월 프록시.
- 숙제: 자원순환과(02-2680-2836) 데이터 활용 + 기후행동 기회소득 연계 의향 확인.

## Related

- 설계/근거: `~/.gstack/projects/iNtuitionP-ecomap/parkj-main-design-20260627-134321.md`
- 태스크 원본: `~/.gstack/projects/iNtuitionP-ecomap/tasks-eng-review-*.jsonl`
- 테스트 플랜: `~/.gstack/projects/iNtuitionP-ecomap/*-eng-review-test-plan-*.md`
- 디자인 목업: `designs/demo-flow-*.png`, `designs/rest-screens-*.png`
