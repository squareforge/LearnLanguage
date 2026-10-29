#!/usr/bin/env python3
"""Run real AppKit practice windows with in-memory storage and silent audio doubles."""
from pathlib import Path
import argparse
import subprocess
import shutil
import plistlib
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--derived-data', required=True, type=Path)
args = parser.parse_args()
framework = args.derived_data / 'Build/Products/Debug/SnapKit'
with tempfile.TemporaryDirectory(prefix='learnlanguage-practice-ui-') as directory:
    bundle = Path(directory) / 'PracticeUITests.app/Contents'
    (bundle / 'MacOS').mkdir(parents=True)
    (bundle / 'Resources').mkdir()
    executable = bundle / 'MacOS/PracticeUITests'
    (bundle / 'Info.plist').write_bytes(plistlib.dumps({
        'CFBundleIdentifier': 'com.learnlanguage.tests.practice-ui',
        'CFBundleExecutable': 'PracticeUITests',
        'CFBundleName': 'PracticeUITests',
        'CFBundlePackageType': 'APPL',
        'LSUIElement': True,
    }))
    for resource in (root / 'LearnLanguage/Modules/Learning/Resources').glob('*.json'):
        shutil.copyfile(resource, bundle / 'Resources' / resource.name)
    sources = [
        'LearnLanguage/Base/Models/LLAppSettings.swift',
        'LearnLanguage/Base/Models/LLWordFeedback.swift',
        'LearnLanguage/Common/Extensions/NotificationName+Extensions.swift',
        'LearnLanguage/Modules/Learning/Models/LLLearningItem.swift',
        'LearnLanguage/Modules/Learning/Engine/LLPracticeSession.swift',
        'LearnLanguage/Modules/Learning/Managers/LLPracticeSources.swift',
        'LearnLanguage/Modules/Learning/Managers/LLPracticePanelController.swift',
        'LearnLanguage/Modules/Learning/ViewControllers/LLPracticeFloatingViewController.swift',
        'LearnLanguage/Modules/Learning/ViewControllers/LLLearningHomeViewController.swift',
        'LearnLanguage/Modules/Learning/Views/LLPracticeTextView.swift',
        'LearnLanguage/Modules/StatusBar/Managers/LLStatusBarManager.swift',
        'LearnLanguage/Modules/TypingPractice/LLStatusBarTypingPractice.swift',
        'Tools/Tests/PracticeUITestDoubles.swift',
        'Tools/Tests/PracticeUITests.swift',
    ]
    subprocess.run(['xcrun','swiftc','-F',str(framework),'-framework','SnapKit','-Xlinker','-rpath','-Xlinker',str(framework),*[str(root/p) for p in sources],'-o',str(executable)],check=True)
    subprocess.run([str(executable)],check=True,timeout=25)
