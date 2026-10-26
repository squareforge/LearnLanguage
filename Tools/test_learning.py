#!/usr/bin/env python3
"""Compile and run shared practice/source tests without touching app data."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="learnlanguage-tests-") as directory:
    executable = Path(directory) / "LearningTests"
    sources = [
        "LearnLanguage/Modules/Learning/Models/LLLearningItem.swift",
        "LearnLanguage/Modules/Learning/Engine/LLPracticeSession.swift",
        "LearnLanguage/Modules/Learning/Managers/LLPracticeSources.swift",
        "Tools/Tests/LearningTestDoubles.swift",
        "Tools/Tests/LearningTests.swift",
    ]
    subprocess.run(["xcrun", "swiftc", *[str(root / path) for path in sources], "-o", str(executable)], check=True)
    subprocess.run([str(executable), str(root / "LearnLanguage/Modules/Learning/Resources/xingrong_courses.json")], check=True)
