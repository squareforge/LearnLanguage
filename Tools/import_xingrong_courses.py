#!/usr/bin/env python3
"""Import the ordered Xingrong lessons from a pinned Earthworm revision."""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile

REVISION = "eb7afc945def0b4b71c64a21354c1b60970e2495"
DESTINATION = Path(__file__).resolve().parents[1] / "LearnLanguage/Modules/Learning/Resources"


def lesson(source, number):
    items = json.loads((source / f"packages/xingrong-courses/data/courses/{number:02}.json").read_text())
    words = [
        {"en": item["english"].strip(), "zh": item["chinese"].strip(), "ipa": item.get("soundmark", "").strip()}
        for item in items
    ]
    if not words or any(not item["en"] or not item["zh"] for item in words):
        raise ValueError(f"Lesson {number} contains empty exercises")
    return {"id": f"xingrong-{number:02}", "category": "星荣课程", "title": f"第 {number} 课", "words": words}


def import_courses(source):
    revision = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
    if revision != REVISION:
        raise ValueError(f"Expected revision {REVISION}, got {revision}")
    if subprocess.check_output(["git", "-C", str(source), "status", "--porcelain"], text=True).strip():
        raise ValueError("Source checkout must be clean")
    courses = [lesson(source, number) for number in range(1, 56)]
    license_text = (source / "LICENSE").read_bytes()
    DESTINATION.mkdir(parents=True, exist_ok=True)
    (DESTINATION / "xingrong_courses.json").write_text(json.dumps(courses, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (DESTINATION / "Earthworm-LICENSE.txt").write_bytes(license_text)
    (DESTINATION / "Xingrong-SOURCE.md").write_text(
        "# 星荣课程来源\n\n"
        "课程文字、中文释义、音标及排列顺序来自 cuixueshe / Earthworm 的星荣课程。\n\n"
        f"- 上游：https://github.com/cuixueshe/earthworm/tree/{REVISION}/packages/xingrong-courses/data/courses\n"
        f"- 固定版本：{REVISION}\n"
        "- 转换：english → en、chinese → zh、soundmark → ipa；保留课目及条目顺序，裁剪首尾空白。\n"
        "- 导入工具：Tools/import_xingrong_courses.py\n"
        "- 重建：python3 Tools/import_xingrong_courses.py（可用 --source-dir 指向固定版本的干净上游仓库）\n"
        "- 上游仓库许可证：GNU Affero General Public License v3.0，全文见 Earthworm-LICENSE.txt。\n\n"
        "此副本用于本地集成实践。对外分发时须审阅上游课程及软件的适用许可，保留来源、许可和相应的源文件。\n",
        encoding="utf-8",
    )
    print(f"Imported {len(courses)} lessons / {sum(len(c['words']) for c in courses)} items from {REVISION}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, help="Clean Earthworm checkout at the pinned revision")
    args = parser.parse_args()
    if args.source_dir:
        import_courses(args.source_dir.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix="xingrong-import-") as directory:
            source = Path(directory) / "earthworm"
            subprocess.run(["git", "clone", "--filter=blob:none", "--sparse", "https://github.com/cuixueshe/earthworm.git", str(source)], check=True)
            subprocess.run(["git", "-C", str(source), "checkout", REVISION], check=True)
            subprocess.run(["git", "-C", str(source), "sparse-checkout", "set", "packages/xingrong-courses/data/courses"], check=True)
            import_courses(source)
