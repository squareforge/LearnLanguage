#!/usr/bin/env python3
"""Verify the redistributable dictionary without opening or changing app data."""
import hashlib
import json
from pathlib import Path
import sqlite3
import sys

root = Path(__file__).resolve().parents[1]
folder = root / 'LearnLanguage/Resources/InitialDicts'
database = folder / 'LearnLanguage.db'
try:
    manifest = json.loads((folder / 'dictionary-manifest.json').read_text())
    if not database.is_file():
        raise ValueError('缺少 LearnLanguage.db；请从完整仓库获取内置词库资源。')
    digest = hashlib.sha256()
    with database.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    if database.stat().st_size != manifest['bytes'] or digest.hexdigest() != manifest['sha256']:
        raise ValueError('词库与 dictionary-manifest.json 不匹配；更新资源时请同步更新版本、大小和 SHA-256。')
    with sqlite3.connect(database.as_uri() + '?mode=ro&immutable=1', uri=True) as connection:
        if connection.execute('PRAGMA quick_check').fetchall() != [('ok',)]:
            raise ValueError('内置词库未通过 SQLite quick_check。')
        for table in ('categories', 'word_lists', 'words', 'word_examples'):
            connection.execute('SELECT * FROM ' + table + ' LIMIT 0')
    print('Dictionary resource verified (version {}, {} bytes).'.format(manifest['content_version'], manifest['bytes']))
except (OSError, ValueError, KeyError, sqlite3.Error) as error:
    print('error: ' + str(error), file=sys.stderr)
    sys.exit(1)
