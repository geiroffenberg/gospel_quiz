#!/usr/bin/env python3
import json
import time
from pathlib import Path

import requests

BOOKS = [
    ('Genesis', 1, 50), ('Exodus', 2, 40), ('Leviticus', 3, 27), ('Numbers', 4, 36), ('Deuteronomy', 5, 34),
    ('Joshua', 6, 24), ('Judges', 7, 21), ('Ruth', 8, 4), ('1 Samuel', 9, 31), ('2 Samuel', 10, 24),
    ('1 Kings', 11, 22), ('2 Kings', 12, 25), ('1 Chronicles', 13, 29), ('2 Chronicles', 14, 36), ('Ezra', 15, 10),
    ('Nehemiah', 16, 13), ('Esther', 17, 10), ('Job', 18, 42), ('Psalms', 19, 150), ('Proverbs', 20, 31),
    ('Ecclesiastes', 21, 12), ('Song of Solomon', 22, 8), ('Isaiah', 23, 66), ('Jeremiah', 24, 52), ('Lamentations', 25, 5),
    ('Ezekiel', 26, 48), ('Daniel', 27, 12), ('Hosea', 28, 14), ('Joel', 29, 3), ('Amos', 30, 9),
    ('Obadiah', 31, 1), ('Jonah', 32, 4), ('Micah', 33, 7), ('Nahum', 34, 3), ('Habakkuk', 35, 3),
    ('Zephaniah', 36, 3), ('Haggai', 37, 2), ('Zechariah', 38, 14), ('Malachi', 39, 4), ('Matthew', 40, 28),
    ('Mark', 41, 16), ('Luke', 42, 24), ('John', 43, 21), ('Acts', 44, 28), ('Romans', 45, 16),
    ('1 Corinthians', 46, 16), ('2 Corinthians', 47, 13), ('Galatians', 48, 6), ('Ephesians', 49, 6), ('Philippians', 50, 4),
    ('Colossians', 51, 4), ('1 Thessalonians', 52, 5), ('2 Thessalonians', 53, 3), ('1 Timothy', 54, 6), ('2 Timothy', 55, 4),
    ('Titus', 56, 3), ('Philemon', 57, 1), ('Hebrews', 58, 13), ('James', 59, 5), ('1 Peter', 60, 5),
    ('2 Peter', 61, 3), ('1 John', 62, 5), ('2 John', 63, 1), ('3 John', 64, 1), ('Jude', 65, 1), ('Revelation', 66, 22),
]

ROOT = Path(__file__).resolve().parents[1]
OUT_FILE = ROOT / 'assets' / 'bible_structure_nt.json'
CACHE_FILE = ROOT / 'scripts' / 'bible_structure_cache.json'
BASE_URL = 'https://bible-api.com/'
NT_BOOK_MIN = 40


def load_cache():
    if CACHE_FILE.exists():
        return json.loads(CACHE_FILE.read_text(encoding='utf-8'))
    return {}


def save_cache(cache):
    CACHE_FILE.write_text(json.dumps(cache, indent=2, ensure_ascii=False), encoding='utf-8')


def fetch_chapter_count(session, book_name, chapter):
    ref = f'{book_name} {chapter}'.replace(' ', '%20')
    url = f'{BASE_URL}{ref}?translation=kjv'
    wait_seconds = 1.0
    for attempt in range(8):
        response = session.get(url, timeout=30)
        if response.status_code == 200:
            data = response.json()
            verses = data.get('verses', [])
            return max((v.get('verse', 0) for v in verses), default=0)
        if response.status_code == 429:
            time.sleep(wait_seconds)
            wait_seconds = min(wait_seconds * 2, 30)
            continue
        response.raise_for_status()
    raise RuntimeError(f'Rate limited too many times for {book_name} {chapter}')


def main():
    cache = load_cache()
    session = requests.Session()
    result_books = []

    nt_books = [book for book in BOOKS if book[1] >= NT_BOOK_MIN]

    for book_name, book_num, chapter_count in nt_books:
        print(f'{book_name}: {chapter_count} chapters')
        cached_counts = cache.get(book_name, [])
        chapter_verse_counts = list(cached_counts)

        for chapter in range(len(chapter_verse_counts) + 1, chapter_count + 1):
            max_verse = fetch_chapter_count(session, book_name, chapter)
            chapter_verse_counts.append(max_verse)
            cache[book_name] = chapter_verse_counts
            save_cache(cache)
            print(f'  chapter {chapter}: {max_verse} verses')
            time.sleep(0.35)

        result_books.append({
            'book_name': book_name,
            'book': book_num,
            'chapter_verse_counts': chapter_verse_counts,
        })

    OUT_FILE.write_text(
        json.dumps({'books': result_books}, indent=2, ensure_ascii=False),
        encoding='utf-8',
    )
    print(f'wrote {OUT_FILE}')


if __name__ == '__main__':
    main()
