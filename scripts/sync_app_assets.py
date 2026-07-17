"""단일소스(shared/, data/) → 앱 에셋(frontend/assets/data/) 동기화.

Flutter는 프로젝트 루트 밖 에셋을 참조할 수 없어 빌드 전 복사가 필요하다.
정본은 항상 shared/·data/ — frontend/assets/data/ 는 생성물이며 직접 수정 금지.
동기화 검증은 frontend/test/asset_sync_test.dart (flutter test) 와
scripts/contracts/tests/test_asset_sync.py (pytest) 가 CI에서 강제한다.
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "frontend" / "assets" / "data"

SOURCES = [
    ROOT / "shared" / "mapping.json",
    ROOT / "shared" / "rules.json",
    ROOT / "data" / "bins.geocoded.json",
    ROOT / "data" / "policy_cards.json",
]


def main() -> int:
    DEST.mkdir(parents=True, exist_ok=True)
    missing = []
    for src in SOURCES:
        if not src.exists():
            missing.append(src)
            continue
        shutil.copy2(src, DEST / src.name)
        print(f"sync: {src.relative_to(ROOT)} -> frontend/assets/data/{src.name}")
    if missing:
        for m in missing:
            print(f"skip (미생성): {m.relative_to(ROOT)}", file=sys.stderr)
        return 1 if len(missing) == len(SOURCES) else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
