#!/usr/bin/env python3
"""Validate all four checked-in course files without translation/phonetic dependencies."""
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / 'LearnLanguage/Modules/Learning/Resources'
sys.path.insert(0, str(ROOT / 'Tools'))
from import_new_concept_translations import load_alignment, apply_reference_translations, reference_units, standalone
spec = importlib.util.spec_from_file_location('importer', ROOT / 'Tools/import_new_concept_courses.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)

# Regression cases from real dialogue and technical prose: preserve attributions,
# abbreviations, decimals, numbered speech and all characters of the article.
assert importer.split_sentences("'Yes?' asked the inspector. 'No.'") == ["'Yes?' asked the inspector.", "'No.'"]
assert importer.split_sentences('Mr. Brown left. It was 8.25.') == ['Mr. Brown left.', 'It was 8.25.']
assert importer.split_sentences("1. 'It is impossible.' 2. 'It is possible.'") == ["1. 'It is impossible.'", "2. 'It is possible.'"]
assert importer.clean_text('We saw Mr.Richards:hello! Next:5, 000.') == 'We saw Mr. Richards: hello! Next:5,000.'
assert reference_units('安  娜：我的帽子\n也是新的。\n路易丝：谢谢。\n安  娜：不客气。', 1) == ['我的帽子也是新的。', '谢谢。', '不客气。']
assert standalone('我说：“别开得这样快！') == '我说：“别开得这样快！”'
assert standalone('什么事？”有人叫着。') == '“什么事？”有人叫着。'
assert standalone('他说：“波淋正在打信，') == '他说：“波淋正在打信。”'

alignment = load_alignment()
books = [json.loads((RESOURCES / f'new_concept_book_{book}.json').read_text()) for book in range(1, 5)]
original = json.dumps(books, ensure_ascii=False)
apply_reference_translations(books, alignment)
assert json.dumps(books, ensure_ascii=False) == original, 'Checked-in translations differ from the recorded reference alignment'
# Detect stale sentence order before reapplying any reference translations.
import copy
reordered = copy.deepcopy(books)
words = reordered[0]['courses'][0]['words']
words[0], words[1] = words[1], words[0]
try:
    apply_reference_translations(reordered, alignment)
except ValueError:
    pass
else:
    raise AssertionError('Reordered English must reject the translation alignment')

by_id = {course['id']: course for book in books for course in book['courses']}
assert by_id['nce-1-lesson-023']['words'][0]['zh'] == '请拿给我几只玻璃杯，简。'
assert by_id['nce-1-lesson-053']['words'][8]['zh'] == '白天长而夜晚短。'
assert by_id['nce-2-lesson-001']['words'][14]['zh'] == '我生气地说。'
assert '不要打断' not in by_id['nce-2-lesson-015']['words'][7]['zh']
assert '不要打断' in by_id['nce-2-lesson-015']['words'][8]['zh']
assert by_id['nce-2-lesson-026']['words'][-1]['zh'] == '画确实挂倒了！'
assert '1925' in by_id['nce-4-lesson-045']['words'][23]['zh']
assert by_id['nce-4-lesson-048']['words'][5]['zh'] == '有什么启示呢？'

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
print('All 276 lessons have aligned TXT Chinese and word-separated British IPA; source, sentence order, translation exceptions and splitting checks passed.')
