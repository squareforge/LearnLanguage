#!/usr/bin/env python3
"""Import the user's four LRC books, with aligned TXT translations and British IPA.

Generation dependencies: phonemizer==3.4.0, espeak-ng==1.52.0.
Only LRC files are read; originals and MP3s are never modified or copied.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import tempfile

from import_new_concept_translations import apply_reference_translations, TRANSLATION_SOURCE

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / 'LearnLanguage/Modules/Learning/Resources'
EXPECTED = {1: 72, 2: 96, 3: 60, 4: 48}
BOOK_NAMES = {1: '第一册', 2: '第二册', 3: '第三册', 4: '第四册'}
OVERRIDES = json.loads((ROOT / 'Tools/new_concept_overrides.json').read_text(encoding='utf-8'))


def decode_lrc(path):
    raw = path.read_bytes()
    for encoding in ('utf-8-sig', 'gb18030', 'utf-16'):
        try:
            return raw.decode(encoding), encoding
        except UnicodeError:
            pass
    raise ValueError('Cannot decode ' + str(path))


def clean_text(text):
    text = text.replace('\ufeff', '').replace('\xa0', ' ')
    text = text.replace('’', "'").replace('‘', "'").replace('“', '"').replace('”', '"')
    text = re.sub(r'(?<=\d),\s+(?=\d{3}\b)', ',', text)
    text = re.sub(r'(?<=[a-zA-Z])([,:;!?])(?=[a-zA-Z])', r'\1 ', text)
    text = re.sub(r'\b(Mr|Mrs|Ms|Dr|St)\.(?=[A-Z])', r'\1. ', text)
    text = re.sub(r'\s*--\s*', ' — ', text)
    return re.sub(r'\s+', ' ', text).strip()


def split_sentences(article):
    # Protect titles, initials, dotted acronyms and time abbreviations. Keep quoted
    # speech with its lower-case attribution ("...?' asked the inspector.").
    protected = re.sub(r'\b(?:Mr|Mrs|Ms|Dr|St|Prof|Rev|No)\.',
                       lambda m: m[0].replace('.', '\ue000'), article)
    protected = re.sub(r'\b(?:[A-Za-z]\.){2,}|\b[A-Z]\.(?=\s+[A-Z])',
                       lambda m: m[0].replace('.', '\ue000'), protected)
    protected = re.sub(r'''\b\d+\.(?=\s+["'])''',
                       lambda m: m[0].replace('.', '\ue000'), protected)
    protected = re.sub(r'''([.!?]["']*)\s+(?=["']*[A-Z0-9])''', r'\1\n', protected)
    return [s.replace('\ue000', '.').strip() for s in protected.splitlines() if s.strip()]


def parse_course(path, book):
    content, encoding = decode_lrc(path)
    lesson = int(re.match(r'\d+', path.name).group())
    title_match = re.search(r'^\[ti:(.*?)\]', content, re.M)
    title = title_match.group(1).strip() if title_match else re.sub(r'^\d+(?:-\d+)?[－—-]', '', path.stem)
    rows = []
    excluded = []
    for line in content.splitlines():
        if not re.match(r'^\[\d+:\d+(?:\.\d+)?\]', line):
            continue
        text = re.sub(r'^(?:\[[^]]+\])+', '', line).strip()
        if not text:
            continue
        if re.search(r'https?://|www\.', text, re.I) or not re.search('[A-Za-z]', text):
            excluded.append(text)
            continue
        rows.append(clean_text(text))
    # Every supplied lesson has an opening comprehension question. Everything through
    # it is introductory material, not part of the article or dialogue to type.
    def comparable(text):
        return re.sub('[^a-z0-9]', '', text.lower())
    while rows and (re.match(r'^Lesson\s+\d+', rows[0], re.I)
                    or comparable(rows[0]) == comparable(title)
                    or re.match(r'^Listen to the tape', rows[0], re.I)):
        excluded.append(rows.pop(0))
    # A dialogue title may itself be a question. The title has already been removed.
    question_end = next((i for i, text in enumerate(rows[:4]) if '?' in text), None)
    if question_end is None:
        raise ValueError('Opening question needs review: ' + str(path))
    excluded.extend(rows[:question_end + 1])
    rows = rows[question_end + 1:]
    article = ' '.join(rows)
    # A missing sentence stop in the supplied Book 4 / Lesson 24 subtitle.
    if book == 4 and lesson == 24:
        article = article.replace('lies beyond It is difficult', 'lies beyond. It is difficult')
    sentences = split_sentences(article)
    if book == 2 and lesson == 71:
        sentences = [part for sentence in sentences for part in re.split(r'(?<=B\.B\.C\.)\s+(?=If )', sentence)]
    if not sentences or any(not re.search('[A-Za-z]', s) for s in sentences):
        raise ValueError('Invalid sentence split: ' + str(path))
    # Require lossless segmentation after whitespace normalization.
    if re.sub(r'\s+', '', ''.join(sentences)) != re.sub(r'\s+', '', article):
        raise ValueError('Sentence split lost source text: ' + str(path))
    return {
        'id': 'nce-{}-lesson-{:03d}'.format(book, lesson),
        'category': '新概念英语' + BOOK_NAMES[book],
        'title': 'Lesson {} · {}'.format(lesson, title),
        'lessonNumber': lesson,
        'sourceFile': path.name,
        'words': [{'en': sentence} for sentence in sentences],
    }, {
        'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'encoding': encoding, 'excludedIntro': excluded, 'sentences': len(sentences),
    }


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(value, ensure_ascii=False, indent=2) + '\n'
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent, delete=False) as handle:
        handle.write(data)
        temp = Path(handle.name)
    temp.replace(path)


def generate_ipa(books):
    from phonemizer.backend import EspeakBackend
    from phonemizer.separator import Separator
    backend = EspeakBackend(language='en-gb-x-rp', with_stress=True, preserve_punctuation=False,
                            language_switch='remove-flags', words_mismatch='ignore')
    items = [item for book in books for course in book['courses'] for item in course['words']]
    def lexical_tokens(text):
        result = []
        for token in text.split():
            token = token.strip('.,!?;:"\'()[]{}—£￡$%')
            if token and re.search('[A-Za-z0-9]', token):
                result.append(token)
        return result
    vocabulary = sorted({token for item in items for token in lexical_tokens(item['en'])})
    phonetics = backend.phonemize(vocabulary, separator=Separator(phone='', word=' ', syllable=''), strip=True, njobs=1)
    lookup = dict(zip(vocabulary, phonetics))
    # Sentence phonemization can join "of the", "has been", etc. Generate lexical
    # tokens separately to guarantee one /.../ group per written word. Use common
    # neutral weak forms; homographs and proper names remain generated references.
    weak = {'a': 'ə', 'an': 'ən', 'to': 'tə', 'of': 'əv', 'and': 'ənd'}
    for item in items:
        parts = []
        for token in lexical_tokens(item['en']):
            ipa = OVERRIDES['phonetics'].get(token.lower(), weak.get(token.lower(), lookup[token])).strip()
            if not ipa or re.search(r'\d|\(en\)', ipa):
                raise ValueError('IPA generation failed: ' + token + ' -> ' + ipa)
            parts.append('/' + ipa + '/')
        if not parts:
            raise ValueError('Empty phonetic sentence')
        item['ipa'] = ' '.join(parts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True)
    parser.add_argument('--cache-dir', type=Path, help=argparse.SUPPRESS)  # Accept the obsolete argument for older local commands.
    parser.add_argument('--output-dir', type=Path, default=RESOURCES)
    parser.add_argument('--parse-only', action='store_true')
    args = parser.parse_args()
    books = []
    report = []
    for book in range(1, 5):
        folders = [p for p in args.source_dir.iterdir() if p.is_dir() and '第{}册'.format(book) in p.name]
        if len(folders) != 1:
            raise ValueError('Expected exactly one folder for book ' + str(book))
        files = sorted(folders[0].glob('*.lrc'), key=lambda p: int(re.match(r'\d+', p.name).group()))
        if len(files) != EXPECTED[book]:
            raise ValueError('Unexpected lesson count for book ' + str(book))
        courses = []
        audits = []
        for path in files:
            course, audit = parse_course(path, book)
            courses.append(course)
            audits.append(audit)
        numbers = [course['lessonNumber'] for course in courses]
        expected = list(range(1, 144, 2)) if book == 1 else list(range(1, EXPECTED[book] + 1))
        if numbers != expected:
            raise ValueError('Missing or duplicated lesson numbers in book ' + str(book))
        books.append({'id': 'new-concept-book-' + str(book), 'title': '新概念英语' + BOOK_NAMES[book],
                      'schemaVersion': 1, 'translation': TRANSLATION_SOURCE,
                      'phonetics': 'eSpeak NG 1.52.0 en-gb-x-rp; generated word-separated IPA reference',
                      'courses': courses})
        report.append({'book': book, 'lessons': audits})
        print('Book {}: {} lessons, {} sentences'.format(book, len(courses), sum(len(c['words']) for c in courses)), flush=True)
    if args.parse_only:
        write_json(args.output_dir / 'new_concept_parsed.json', books)
        write_json(args.output_dir / 'new_concept_import_audit.json', report)
        return
    # Never regenerate the old machine translations over the supplied reference.
    # Alignment checks the exact English sequence before applying any translation.
    apply_reference_translations(books)
    generate_ipa(books)
    for index, book in enumerate(books, 1):
        write_json(args.output_dir / 'new_concept_book_{}.json'.format(index), book)
    write_json(args.output_dir / 'new_concept_import_audit.json', report)
    print('Imported all four books.', flush=True)


if __name__ == '__main__':
    main()
