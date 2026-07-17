# -*- coding: utf-8 -*-
"""T4 · mapping-single-source — Acceptance 3(앱·스크립트 동일 파일 참조) 강제 테스트.

SPEC.md 137행: "앱과 스크립트가 **같은 파일**을 참조(중복 정의 0 — grep으로 확인)."

검증 항목:
- frontend/assets/data/ 에 mapping.json·rules.json 이 동기화되어 있고 정본(shared/)과 동일
- 앱 로더 frontend/lib/shared/mapping_loader.dart 가 존재하며 동기화된 에셋 경로를 참조
- 앱 Dart 코드에 매핑 중복 정의 0 (CSV 플래그 문자열 리터럴 grep == 0건)
- sync_app_assets.py docstring 이 주장하는 frontend/test/asset_sync_test.dart 실존
- sync 스크립트 재실행 멱등(rc 0, 산출물 정본과 동일 유지)
"""
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SHARED = REPO_ROOT / "shared"
APP_ASSETS = REPO_ROOT / "frontend" / "assets" / "data"
APP_LIB = REPO_ROOT / "frontend" / "lib"
MAPPING_LOADER = APP_LIB / "shared" / "mapping_loader.dart"
DART_SYNC_TEST = REPO_ROOT / "frontend" / "test" / "asset_sync_test.dart"
SYNC_SCRIPT = REPO_ROOT / "scripts" / "sync_app_assets.py"

# CSV 15플래그 — 앱 Dart 코드에 이 리터럴이 있으면 매핑 중복 정의(단일 소스 위반)
CSV_FLAGS_15 = [
    "일반쓰레기", "종이", "종이팩", "금속캔", "고철", "플라스틱", "무색페트병",
    "유리병", "비닐", "스티로폼", "건전지", "형광등", "소형전자제품", "식용유", "의류",
]


def _load_json(path: Path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


class TestSyncedAssets:
    def test_mapping_synced_and_identical_to_source(self):
        """frontend/assets/data/mapping.json 존재 + 정본 shared/mapping.json 과 내용 동일."""
        synced = APP_ASSETS / "mapping.json"
        assert synced.exists(), f"미동기화: {synced} 없음 — scripts/sync_app_assets.py 실행 필요"
        assert _load_json(synced) == _load_json(SHARED / "mapping.json"), (
            "frontend/assets/data/mapping.json 이 정본 shared/mapping.json 과 다름"
        )

    def test_rules_synced_and_identical_to_source(self):
        """frontend/assets/data/rules.json 존재 + 정본 shared/rules.json 과 내용 동일."""
        synced = APP_ASSETS / "rules.json"
        assert synced.exists(), f"미동기화: {synced} 없음 — scripts/sync_app_assets.py 실행 필요"
        assert _load_json(synced) == _load_json(SHARED / "rules.json"), (
            "frontend/assets/data/rules.json 이 정본 shared/rules.json 과 다름"
        )


class TestAppReferencesSameFile:
    def test_mapping_loader_exists(self):
        """SPEC T4 Files: 앱 로더(mapping_loader.dart) 실존."""
        assert MAPPING_LOADER.exists(), f"{MAPPING_LOADER} 없음 (SPEC T4 Files)"

    def test_mapping_loader_reads_synced_assets(self):
        """로더가 동기화된 에셋(assets/data/mapping.json·rules.json)을 참조."""
        src = MAPPING_LOADER.read_text(encoding="utf-8")
        assert "assets/data/mapping.json" in src, "로더가 assets/data/mapping.json 미참조"
        assert "assets/data/rules.json" in src, "로더가 assets/data/rules.json 미참조"

    def test_no_duplicate_mapping_definition_in_dart(self):
        """중복 정의 0: 앱 Dart 코드에 CSV 플래그 리터럴이 하드코딩되면 안 됨."""
        offenders = []
        for dart in APP_LIB.rglob("*.dart"):
            src = dart.read_text(encoding="utf-8")
            hits = [flag for flag in CSV_FLAGS_15 if flag in src]
            if hits:
                offenders.append((str(dart.relative_to(REPO_ROOT)), hits))
        assert not offenders, f"Dart 코드 내 매핑 중복 정의(플래그 리터럴): {offenders}"


class TestSyncScriptClaims:
    def test_docstring_referenced_dart_test_exists(self):
        """sync_app_assets.py docstring 이 주장하는 Dart 동기화 테스트가 실존해야 함."""
        doc = SYNC_SCRIPT.read_text(encoding="utf-8")
        if "asset_sync_test.dart" in doc:
            assert DART_SYNC_TEST.exists(), (
                "sync_app_assets.py 가 frontend/test/asset_sync_test.dart 를 주장하나 파일 없음"
            )

    def test_dart_sync_test_exists_and_compares_source(self):
        """Dart 테스트가 실존하고 정본(shared/)과의 비교를 수행."""
        assert DART_SYNC_TEST.exists(), f"{DART_SYNC_TEST} 없음"
        src = DART_SYNC_TEST.read_text(encoding="utf-8")
        assert "../shared/mapping.json" in src, "Dart 테스트가 정본 mapping.json 미비교"
        assert "../shared/rules.json" in src, "Dart 테스트가 정본 rules.json 미비교"

    def test_sync_script_rerun_is_idempotent(self):
        """sync 재실행 rc==0, 산출물은 정본과 동일 유지."""
        proc = subprocess.run(
            [sys.executable, str(SYNC_SCRIPT)],
            capture_output=True,
            cwd=str(REPO_ROOT),
        )
        assert proc.returncode == 0, f"sync rc={proc.returncode}: {proc.stderr!r}"
        for name in ("mapping.json", "rules.json"):
            assert _load_json(APP_ASSETS / name) == _load_json(SHARED / name)
