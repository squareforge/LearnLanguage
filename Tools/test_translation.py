#!/usr/bin/env python3
"""Exercise the production view model with controlled service responses and no real clipboard/translation access."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='learnlanguage-translation-tests-') as directory:
    executable = Path(directory) / 'TranslationTests'
    sources = [
        'LearnLanguage/Modules/Translation/Managers/LLTranslateViewModel.swift',
        'LearnLanguage/Common/Extensions/NotificationName+Extensions.swift',
        'Tools/Tests/TranslationTestDoubles.swift',
        'Tools/Tests/TranslationTests.swift',
    ]
    subprocess.run(['xcrun','swiftc',*[str(root/p) for p in sources],'-o',str(executable)],check=True)
    subprocess.run([str(executable)],check=True)
