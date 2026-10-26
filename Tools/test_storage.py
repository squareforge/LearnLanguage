#!/usr/bin/env python3
"""Run storage regressions exclusively in temporary directories, never app storage."""
from pathlib import Path
import argparse
import sqlite3
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--derived-data', type=Path, help='Also run actual WCDB/MMKV integration tests using built framework products')
parser.add_argument('--full-dictionary', action='store_true', help='Also migrate a temporary copy of the full bundled dictionary with the native SQLite engine')
args = parser.parse_args()
if args.full_dictionary and not args.derived_data:
    parser.error('--full-dictionary requires --derived-data')


def fixture(path, resource=False):
    bundled = root / 'LearnLanguage/Resources/InitialDicts/LearnLanguage.db'
    source = sqlite3.connect(bundled.as_uri() + '?mode=ro&immutable=1', uri=True)
    db = sqlite3.connect(path)
    for table in ['categories', 'word_lists', 'words', 'word_examples']:
        db.execute(source.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name=?", (table,)).fetchone()[0])
    source.close()
    db.execute("INSERT INTO categories(id,name) VALUES(1,'shared-category')")
    if resource:
        db.executemany('INSERT INTO word_lists(id,category_id,name) VALUES(?,1,?)', [(1,'library-A'), (2,'library-B'), (3,'new-library')])
        db.executemany('INSERT INTO words(word_list_id,word,translation) VALUES(?,?,?)', [(1,'apple','updated apple'),(1,'new-apple','new'),(2,'banana','banana'),(3,'cherry','cherry')])
        db.execute("INSERT INTO word_examples(word_text,sentence_en,sentence_cn) VALUES('apple','An apple.','一个苹果。')")
    else:
        db.executemany('INSERT INTO word_lists(id,category_id,name) VALUES(?,1,?)', [(10,'library-A'),(20,'library-B'),(30,'custom-notebook')])
        db.execute("INSERT INTO words(id,word_list_id,word,translation) VALUES(101,10,'apple','old apple')")
        db.execute('CREATE TABLE preserved_progress(word_id INTEGER, marker TEXT)')
        db.execute("INSERT INTO preserved_progress VALUES(101,'learned')")
    db.commit()
    db.close()


with tempfile.TemporaryDirectory(prefix='learnlanguage-storage-tests-') as directory:
    temp = Path(directory)
    fixture(temp / 'resource.db', resource=True)
    fixture(temp / 'legacy.db')
    core_sources = [
        'LearnLanguage/Base/Storage/LLBackupArchive.swift',
        'LearnLanguage/Base/Storage/LLFileReplacementTransaction.swift',
        'LearnLanguage/Base/Storage/Database/LLSQLiteConnection.swift',
        'LearnLanguage/Base/Storage/Database/LLContentMigrator.swift',
        'Tools/Tests/StorageCoreTests.swift',
    ]
    executable = temp / 'StorageCoreTests'
    subprocess.run(['xcrun','swiftc',*[str(root / p) for p in core_sources],'-o',str(executable)],check=True)
    subprocess.run([str(executable),str(temp)],check=True)
    if args.derived_data:
        fixture(temp / 'integration.db')
        integration = root / 'Tools/Tests/StorageIntegrationTests.swift'
        if not integration.exists():
            raise SystemExit('Missing storage integration test source')
        products = args.derived_data / 'Build/Products/Debug'
        framework_dirs = [products / p for p in ['WCDB.swift','MMKV','MMKVCore','WCDBOptimizedSQLCipher','SQLiteRepairKit']]
        dependencies = []
        for folder in framework_dirs:
            dependencies += ['-F',str(folder),'-Xlinker','-rpath','-Xlinker',str(folder)]
        # Exercise the app's bundled SQLite version too, rather than relying on the OS version.
        native_root = temp / 'native-core'
        native_root.mkdir()
        fixture(native_root / 'resource.db', resource=True)
        fixture(native_root / 'legacy.db')
        native_core = temp / 'StorageNativeCoreTests'
        subprocess.run(['xcrun','swiftc',*dependencies,'-framework','sqlcipher',*[str(root/p) for p in core_sources],'-o',str(native_core)],check=True)
        native_arguments = [str(native_core),str(native_root)]
        if args.full_dictionary:
            native_arguments.append(str(root / 'LearnLanguage/Resources/InitialDicts/LearnLanguage.db'))
        subprocess.run(native_arguments,check=True)
        sources = core_sources[:-1] + [
            'LearnLanguage/Base/Storage/LLMMKVKeys.swift',
            'LearnLanguage/Base/Storage/LLMMKVManager.swift',
            'LearnLanguage/Base/Storage/LLSettingsStore.swift',
            'LearnLanguage/Base/Models/LLAppSettings.swift',
            'LearnLanguage/Base/Models/LLWordEntry.swift',
            'LearnLanguage/Base/Models/LLWordFeedback.swift',
            'LearnLanguage/Base/Storage/LLWordListStorage.swift',
            'LearnLanguage/Base/Managers/LLDailyLearningManager.swift',
            'LearnLanguage/Common/Extensions/NotificationName+Extensions.swift',
            'LearnLanguage/Base/Storage/Database/LLDatabaseManager.swift',
            *[str(p.relative_to(root)) for p in (root/'LearnLanguage/Base/Storage/Database').glob('LLDB*.swift')],
            'Tools/Tests/StorageIntegrationDoubles.swift',
            'Tools/Tests/StorageIntegrationTests.swift',
        ]
        executable = temp / 'StorageIntegrationTests'
        subprocess.run(['xcrun','swiftc',*dependencies,'-framework','WCDBSwift','-framework','MMKV','-framework','MMKVCore',*[str(root/p) for p in sources],'-o',str(executable)],check=True)
        subprocess.run([str(executable),str(temp)],check=True)
