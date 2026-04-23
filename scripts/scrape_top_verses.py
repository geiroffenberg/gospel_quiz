#!/usr/bin/env python3
"""
Scrape top Bible verses from topverses.com with KJV text.

Outputs:
    assets/top_777_nt.json      — NT-only top 777 verses (books 40-66)

Run from the gospel_quiz project root:
  python3 scripts/scrape_top_verses.py

Progress is cached in scripts/verse_cache.json so the script can be safely
interrupted and restarted without re-fetching already-downloaded pages.
"""

import json
import os
import re
import time
import requests
from bs4 import BeautifulSoup

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
BASE_URL = "https://www.topverses.com"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(SCRIPT_DIR, "../assets")
CACHE_FILE = os.path.join(SCRIPT_DIR, "verse_cache.json")
OUTPUT_NT = os.path.join(ASSETS_DIR, "top_777_nt.json")

DELAY = 0.8          # seconds between HTTP requests (be polite)
TARGET = 1000        # source rank list size to collect before filtering NT subset
NT_TARGET = 777      # number of NT verses used by the app
NT_BOOK_MIN = 40     # Matthew = 40 in standard numbering

# ---------------------------------------------------------------------------
# Book name mapping: URL slug → (display name, book number)
# ---------------------------------------------------------------------------
BOOK_MAP = {
    "Genesis":         ("Genesis", 1),
    "Exodus":          ("Exodus", 2),
    "Leviticus":       ("Leviticus", 3),
    "Numbers":         ("Numbers", 4),
    "Deuteronomy":     ("Deuteronomy", 5),
    "Joshua":          ("Joshua", 6),
    "Judges":          ("Judges", 7),
    "Ruth":            ("Ruth", 8),
    "1Samuel":         ("1 Samuel", 9),
    "2Samuel":         ("2 Samuel", 10),
    "1Kings":          ("1 Kings", 11),
    "2Kings":          ("2 Kings", 12),
    "1Chronicles":     ("1 Chronicles", 13),
    "2Chronicles":     ("2 Chronicles", 14),
    "Ezra":            ("Ezra", 15),
    "Nehemiah":        ("Nehemiah", 16),
    "Esther":          ("Esther", 17),
    "Job":             ("Job", 18),
    "Psalms":          ("Psalms", 19),
    "Proverbs":        ("Proverbs", 20),
    "Ecclesiastes":    ("Ecclesiastes", 21),
    "SongofSolomon":   ("Song of Solomon", 22),
    "Isaiah":          ("Isaiah", 23),
    "Jeremiah":        ("Jeremiah", 24),
    "Lamentations":    ("Lamentations", 25),
    "Ezekiel":         ("Ezekiel", 26),
    "Daniel":          ("Daniel", 27),
    "Hosea":           ("Hosea", 28),
    "Joel":            ("Joel", 29),
    "Amos":            ("Amos", 30),
    "Obadiah":         ("Obadiah", 31),
    "Jonah":           ("Jonah", 32),
    "Micah":           ("Micah", 33),
    "Nahum":           ("Nahum", 34),
    "Habakkuk":        ("Habakkuk", 35),
    "Zephaniah":       ("Zephaniah", 36),
    "Haggai":          ("Haggai", 37),
    "Zechariah":       ("Zechariah", 38),
    "Malachi":         ("Malachi", 39),
    "Matthew":         ("Matthew", 40),
    "Mark":            ("Mark", 41),
    "Luke":            ("Luke", 42),
    "John":            ("John", 43),
    "Acts":            ("Acts", 44),
    "Romans":          ("Romans", 45),
    "1Corinthians":    ("1 Corinthians", 46),
    "2Corinthians":    ("2 Corinthians", 47),
    "Galatians":       ("Galatians", 48),
    "Ephesians":       ("Ephesians", 49),
    "Philippians":     ("Philippians", 50),
    "Colossians":      ("Colossians", 51),
    "1Thessalonians":  ("1 Thessalonians", 52),
    "2Thessalonians":  ("2 Thessalonians", 53),
    "1Timothy":        ("1 Timothy", 54),
    "2Timothy":        ("2 Timothy", 55),
    "Titus":           ("Titus", 56),
    "Philemon":        ("Philemon", 57),
    "Hebrews":         ("Hebrews", 58),
    "James":           ("James", 59),
    "1Peter":          ("1 Peter", 60),
    "2Peter":          ("2 Peter", 61),
    "1John":           ("1 John", 62),
    "2John":           ("2 John", 63),
    "3John":           ("3 John", 64),
    "Jude":            ("Jude", 65),
    "Revelation":      ("Revelation", 66),
}

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    )
}

# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------
def get_html(url, retries=3):
    for attempt in range(1, retries + 1):
        try:
            r = requests.get(url, headers=HEADERS, timeout=20)
            r.raise_for_status()
            return r.text
        except Exception as e:
            print(f"  [attempt {attempt}/{retries}] Error fetching {url}: {e}")
            time.sleep(3)
    return None

# ---------------------------------------------------------------------------
# Step 1: scrape ranked list pages to get verse references in order
# ---------------------------------------------------------------------------
VERSE_LINK_RE = re.compile(r"^/Bible/([^/]+)/(\d+)/(\d+)$")

def scrape_list_page(page_num):
    """Return list of (book_slug, chapter, verse) from a ranked list page."""
    url = f"{BASE_URL}/Bible/&pg={page_num}"
    html = get_html(url)
    if not html:
        return []
    soup = BeautifulSoup(html, "html.parser")
    results = []
    seen = set()
    for a in soup.find_all("a", href=VERSE_LINK_RE):
        href = a["href"]
        m = VERSE_LINK_RE.match(href)
        if m:
            book, ch, vs = m.group(1), int(m.group(2)), int(m.group(3))
            key = (book, ch, vs)
            if key not in seen:
                seen.add(key)
                results.append(key)
    return results

# ---------------------------------------------------------------------------
# Step 2: extract KJV text from individual verse pages
# ---------------------------------------------------------------------------
def extract_kjv(html, verse_num):
    """
    Find the 'King James Version' section and return the text of the focal verse.

    Page structure inside the KJV section:
      <span class="crumbs"><a href="/Bible/Book/Ch/15">15</a></span>
      <span>That whosoever believeth...</span>
      <span class="crumbs"><a href="/Bible/Book/Ch/16">16</a></span>
      <span style="color:red;">For God so loved the world...</span>  ← focal verse

    The focal verse text span has style="color:red;" (highlighted).
    We find the KJV heading, then the <span class="crumbs"> containing the target
    verse number, then return the text of its next sibling <span>.
    """
    soup = BeautifulSoup(html, "html.parser")

    # Locate the KJV section heading
    kjv_heading = None
    for tag in soup.find_all(True):
        if re.search(r"king james", tag.get_text(), re.IGNORECASE):
            if tag.name in ("h2", "h3", "h4", "h5", "strong", "b"):
                kjv_heading = tag
                break

    if not kjv_heading:
        return None

    verse_str = str(verse_num)

    # Find <span class="crumbs"> elements after KJV heading that wrap the target
    # verse number link, then return the text of the next sibling <span>.
    for crumbs in kjv_heading.find_all_next("span", class_="crumbs"):
        a = crumbs.find("a")
        if a and a.get_text(strip=True) == verse_str:
            text_span = crumbs.find_next_sibling("span")
            if text_span:
                text = text_span.get_text(strip=True)
                if len(text) > 10:
                    return text
            break

    return None


def fetch_verse_kjv(book_slug, chapter, verse):
    url = f"{BASE_URL}/Bible/{book_slug}/{chapter}/{verse}"
    html = get_html(url)
    if not html:
        return None
    return extract_kjv(html, verse)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    os.makedirs(ASSETS_DIR, exist_ok=True)

    # Load cache (stores already-fetched KJV texts keyed by "Book/Ch/V")
    cache = {}
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, encoding="utf-8") as f:
            cache = json.load(f)
        print(f"Cache loaded: {len(cache)} verses already fetched")

    # ---- Step 1: collect ranked references ----
    print(f"\n=== Step 1: collecting top {TARGET} verse references ===")
    refs = []
    page = 1
    while len(refs) < TARGET:
        print(f"  List page {page} (have {len(refs)} refs so far)...")
        page_refs = scrape_list_page(page)
        if not page_refs:
            print(f"  Empty page {page}, stopping.")
            break
        refs.extend(page_refs)
        page += 1
        time.sleep(DELAY)

    refs = refs[:TARGET]
    print(f"Collected {len(refs)} verse references\n")

    # ---- Step 2: fetch KJV text for each verse ----
    print(
        f"=== Step 2: fetching KJV text ({TARGET} requests, "
        f"~{TARGET * DELAY / 60:.0f} min) ==="
    )
    verses = []
    failed = []

    for i, (book_slug, chapter, verse_num) in enumerate(refs, 1):
        rank = i
        cache_key = f"{book_slug}/{chapter}/{verse_num}"

        if cache_key in cache:
            kjv_text = cache[cache_key]
            status = "cached"
        else:
            print(
                f"  [{rank:>4}/{TARGET}] {book_slug} {chapter}:{verse_num}  ",
                end="",
                flush=True,
            )
            kjv_text = fetch_verse_kjv(book_slug, chapter, verse_num)
            if kjv_text:
                cache[cache_key] = kjv_text
                with open(CACHE_FILE, "w", encoding="utf-8") as f:
                    json.dump(cache, f)
                status = "OK"
            else:
                status = "FAILED"
                failed.append(cache_key)
            print(status)
            time.sleep(DELAY)

        book_info = BOOK_MAP.get(book_slug)
        if not book_info:
            print(f"  WARNING: Unknown book slug '{book_slug}' — skipping")
            continue

        display_name, book_num = book_info
        verses.append({
            "rank":      rank,
            "book_name": display_name,
            "book":      book_num,
            "chapter":   chapter,
            "verse":     verse_num,
            "text":      kjv_text or "",
        })

    # ---- Save NT-only output used by the app ----
    nt_verses = [v for v in verses if v["book"] >= NT_BOOK_MIN][:NT_TARGET]
    with open(OUTPUT_NT, "w", encoding="utf-8") as f:
        json.dump({"verses": nt_verses}, f, indent=2, ensure_ascii=False)
    print(f"\nSaved {len(nt_verses)} NT verses → {OUTPUT_NT}")

    if failed:
        print(f"\nWARNING: Failed to fetch KJV text for {len(failed)} verses:")
        for k in failed:
            print(f"  {k}")
    else:
        print("\nAll verses fetched successfully!")


if __name__ == "__main__":
    main()
