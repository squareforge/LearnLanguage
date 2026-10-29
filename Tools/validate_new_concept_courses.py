#!/usr/bin/env python3
"""Validate all four checked-in course files without translation/phonetic dependencies."""
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / 'LearnLanguage/Modules/Learning/Resources'
spec = importlib.util.spec_from_file_location('importer', ROOT / 'Tools/import_new_concept_courses.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)

# Regression cases from real dialogue and technical prose: preserve attributions,
# abbreviations, decimals, numbered speech and all characters of the article.
assert importer.split_sentences("'Yes?' asked the inspector. 'No.'") == ["'Yes?' asked the inspector.", "'No.'"]
assert importer.split_sentences('Mr. Brown left. It was 8.25.') == ['Mr. Brown left.', 'It was 8.25.']
assert importer.split_sentences("1. 'It is impossible.' 2. 'It is possible.'") == ["1. 'It is impossible.'", "2. 'It is possible.'"]
assert importer.clean_text('We saw Mr.Richards:hello! Next:5, 000.') == 'We saw Mr. Richards: hello! Next:5,000.'

seen = set()
total = 0
report = json.loads((RESOURCES / 'new_concept_import_audit.json').read_text())
for book, (course_count, item_count) in enumerate([(72, 1214), (96, 1062), (60, 1295), (48, 748)], 1):
    data = json.loads((RESOURCES / f'new_concept_book_{book}.json').read_text())
    assert data['id'] == f'new-concept-book-{book}'
    courses = data['courses']
    assert len(courses) == course_count
    expected_numbers = list(range(1, 144, 2)) if book == 1 else list(range(1, course_count + 1))
    assert [c['lessonNumber'] for c in courses] == expected_numbers
    assert sum(len(c['words']) for c in courses) == item_count
    audit = report[book - 1]['lessons']
    assert len(audit) == course_count
    for course, source in zip(courses, audit):
        assert course['id'] not in seen
        seen.add(course['id'])
        assert course['sourceFile'] == source['file']
        assert len(course['words']) == source['sentences']
        assert re.fullmatch('[0-9a-f]{64}', source['sha256'])
        assert any('?' in text for text in source['excludedIntro'])
        for item in course['words']:
            assert re.search('[A-Za-z]', item['en'])
            assert not re.search(r'https?://|www\.|^Lesson \d|Listen to the tape|\[\d+:\d+', item['en'])
            assert re.search('[\u3400-\u9fff]', item['zh'])
            assert re.fullmatch(r'/[^/]+/(?: /[^/]+/)*', item['ipa'])
            tokens = [t for t in item['en'].split() if re.search('[A-Za-z0-9]', t)]
            assert len(re.findall(r'/[^/]+/', item['ipa'])) == len(tokens), item
            total += 1
    print(f'Book {book}: {course_count} lessons / {item_count} sentences verified')
assert total == 4319
print('All 276 lessons have English, Chinese and word-separated British IPA; source audit and splitting checks passed.')
