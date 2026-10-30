#!/usr/bin/env python3
"""Apply the reviewed, sentence-aligned translations from the user's 1to4 TXT files.

No network or third-party Python packages are required. The checked-in alignment
keeps the source clauses, file hashes and explicit adaptations for missing or
merged translations. English text, IPA and progress identifiers are never edited.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / 'LearnLanguage/Modules/Learning/Resources'
ALIGNMENT = ROOT / 'Tools/new_concept_reference_translations.json'
TRANSLATION_SOURCE = 'User-provided NEW_CONCEPT_ENGLISH/1to4 TXT reference translations; sentence-aligned with documented adaptations'


def english_digest(course):
    return hashlib.sha256(json.dumps([item['en'] for item in course['words']], ensure_ascii=False).encode()).hexdigest()


def reference_units(text, book):
    lines = [re.sub(r'\s+', '', line) for line in text.splitlines() if line.strip()]
    label = re.compile(r'^([^\s:：]{1,8})[:：]')
    def speaker(line):
        return book == 1 and not line.startswith('你听这段') and label.match(line)
    if book == 1 and sum(bool(speaker(line)) for line in lines) >= 3:
        blocks = []
        for line in lines:
            if speaker(line):
                blocks.append(label.sub('', line))
            elif blocks:
                blocks[-1] += line
            else:
                blocks.append(line)
    elif book > 1:
        blocks = [''.join(lines)]
    else:
        blocks = lines
    chunks = []
    for block in blocks:
        block = re.sub(r'(?<=\d)[,，]\s*(?=\d{3}(?:\D|$))', '', block)
        chunks.extend(re.findall(r'.+?(?:[，,、。！？?!；;：:]+[”’」』"]*|$)', block))
    return [chunk for chunk in chunks if chunk]


def standalone(text):
    """Finish a translated clause as one independent exercise, balancing quotes."""
    text = text.strip()
    # Reference dialogue sometimes opens in one exercise and closes in another.
    # Remove unmatched boundary quotation marks; preserve complete quotations.
    for opening, closing in [('“', '”'), ('‘', '’'), ('「', '」'), ('『', '』')]:
        if text.count(opening) != text.count(closing):
            if text.startswith(opening):
                text = text[1:]
            if text.endswith(closing):
                text = text[:-1]
        # An attribution may precede an unfinished quotation, or follow the
        # closing half of a quotation that started in the previous exercise.
        while text.count(opening) < text.count(closing):
            text = opening + text
        while text.count(opening) > text.count(closing):
            text += closing
    if text.count('"') % 2:
        if text.startswith('"'):
            text = text[1:]
        elif text.endswith('"'):
            text = text[:-1]
    if text.endswith(('，', ',', '、', '；', ';', '：', ':')):
        text = text[:-1]
    text = re.sub(r'[，,、；;：:]([”’」』"]+)$', r'。\1', text)
    if text and text[-1] not in '。！？?!”’」』"':
        text += '。'
    return text


def load_alignment(source_dir=None):
    data = json.loads(ALIGNMENT.read_text(encoding='utf-8'))
    assert data['schemaVersion'] == 1
    records = data['lessons']
    assert len(records) == 276
    assert len({record['id'] for record in records}) == 276
    for record in records:
        assert re.fullmatch('[0-9a-f]{64}', record['sourceSHA256'])
        if source_dir is not None:
            path = source_dir / record['sourceFile']
            raw = path.read_bytes()
            if hashlib.sha256(raw).hexdigest() != record['sourceSHA256']:
                raise ValueError('Reference file changed; review the alignment: ' + record['sourceFile'])
            reference = raw.decode('gb18030').split('参考译文')
            if len(reference) != 2 or reference_units(reference[1], record['book']) != record['clauses']:
                raise ValueError('Reference clause mismatch: ' + record['sourceFile'])
        for item in record['items']:
            assert item['clauses'] or (item.get('text') and item.get('note'))
            assert all(0 <= index < len(record['clauses']) for index in item['clauses'])
            assert not item.get('text') or item.get('note')
        used = {index for item in record['items'] for index in item['clauses']}
        unused = {item['index'] for item in record.get('unusedClauses', [])}
        assert not used & unused
        assert used | unused == set(range(len(record['clauses'])))
        assert all(item.get('note') for item in record.get('unusedClauses', []))
    return {record['id']: record for record in records}


def apply_reference_translations(books, alignment=None):
    alignment = load_alignment() if alignment is None else alignment
    visited = set()
    for book in books:
        for course in book['courses']:
            record = alignment.get(course['id'])
            if record is None or course['id'] in visited:
                raise ValueError('Unknown or duplicate course: ' + course['id'])
            if english_digest(course) != record['englishSHA256'] or len(record['items']) != len(course['words']):
                raise ValueError('English sentences changed; review translation alignment: ' + course['id'])
            visited.add(course['id'])
    if visited != set(alignment):
        raise ValueError('Translation alignment does not cover exactly the imported courses')
    for book in books:
        for course in book['courses']:
            record = alignment[course['id']]
            for word, entry in zip(course['words'], record['items']):
                text = entry.get('text') or ''.join(record['clauses'][index] for index in entry['clauses'])
                word['zh'] = standalone(text)
                if not re.search('[\u3400-\u9fff]', word['zh']):
                    raise ValueError('Missing Chinese: ' + course['id'])
        book['translation'] = TRANSLATION_SOURCE


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, help='Optional original 1to4 directory: also verify all TXT hashes and source clauses')
    parser.add_argument('--resource-dir', type=Path, default=RESOURCES)
    parser.add_argument('--check', action='store_true', help='Validate without writing files')
    args = parser.parse_args()
    alignment = load_alignment(args.source_dir)
    paths = [args.resource_dir / f'new_concept_book_{book}.json' for book in range(1, 5)]
    originals = [path.read_text(encoding='utf-8') for path in paths]
    books = [json.loads(text) for text in originals]
    apply_reference_translations(books, alignment)
    for path, original, book in zip(paths, originals, books):
        generated = json.dumps(book, ensure_ascii=False, indent=2) + '\n'
        if args.check:
            if generated != original:
                raise ValueError('Translations need updating: ' + path.name)
        else:
            path.write_text(generated, encoding='utf-8')
        print(f'{path.name}: {len(book["courses"])} lessons / {sum(len(c["words"]) for c in book["courses"])} translations verified')
    print('Verified reference translations; English, IPA, lesson IDs and item order preserved.')


if __name__ == '__main__':
    main()
