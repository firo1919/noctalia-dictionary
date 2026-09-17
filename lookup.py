#!/usr/bin/env python3
"""
Lightweight offline English dictionary lookup engine for Noctalia Dictionary Plugin.
Uses a local indexed SQLite dictionary (Webster/WordNet) with sub-millisecond query latency.
"""

import sys
import os
import re
import json
import sqlite3

DEFAULT_DB_PATH = os.path.expanduser("~/.local/share/noctalia/dictionary/dictionary.db")
LOCAL_DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dictionary.db")

def get_db_connection():
    if os.path.isfile(DEFAULT_DB_PATH):
        return sqlite3.connect(DEFAULT_DB_PATH)
    elif os.path.isfile(LOCAL_DB_PATH):
        return sqlite3.connect(LOCAL_DB_PATH)
    return None

def clean_word(raw):
    # Strip any enclosing punctuation, quotes, brackets, or numbers
    s = raw.strip()
    s = re.sub(r"^[^a-zA-Z]+|[^a-zA-Z]+$", "", s)
    return s.strip().lower()

def lemmatize(word):
    """Generate potential root candidates for plurals and verb inflections."""
    candidates = [word]
    if word.endswith("ies") and len(word) > 4:
        candidates.append(word[:-3] + "y")
    if word.endswith("es") and len(word) > 3:
        candidates.append(word[:-2])
        candidates.append(word[:-1])
    if word.endswith("s") and len(word) > 2 and not word.endswith("ss"):
        candidates.append(word[:-1])
    if word.endswith("ed") and len(word) > 3:
        candidates.append(word[:-2])
        candidates.append(word[:-1])
    if word.endswith("ing") and len(word) > 4:
        candidates.append(word[:-3])
        candidates.append(word[:-3] + "e")
        if len(word) > 5 and word[-4] == word[-5]: # e.g. running -> run
            candidates.append(word[:-4])
    if word.endswith("ly") and len(word) > 3:
        candidates.append(word[:-2])
        candidates.append(word[:-2] + "le")
    return candidates

def lookup(query_text):
    word = clean_word(query_text)
    if not word:
        return {
            "found": False,
            "word": query_text,
            "error": "No valid word selected"
        }

    conn = get_db_connection()
    if not conn:
        return {
            "found": False,
            "word": word,
            "error": "Local dictionary database not found"
        }

    cursor = conn.cursor()
    candidates = lemmatize(word)

    found_word = None
    rows = []

    for cand in candidates:
        cursor.execute("SELECT word, wordtype, definition FROM entries WHERE word = ? COLLATE NOCASE", (cand,))
        results = cursor.fetchall()
        if results:
            found_word = cand
            rows = results
            break

    if not rows:
        # Check prefix suggestions
        cursor.execute("SELECT DISTINCT word FROM entries WHERE word LIKE ? LIMIT 6", (word + "%",))
        suggestions = [r[0] for r in cursor.fetchall()]
        conn.close()
        return {
            "found": False,
            "word": word,
            "suggestions": suggestions,
            "error": f"No definition found for '{word}'"
        }

    conn.close()

    definitions = []
    wordtypes = set()

    for w, wt, d in rows:
        if wt and wt.strip():
            wordtypes.add(wt.strip())
        clean_def = re.sub(r"\s+", " ", d.strip())
        definitions.append(clean_def)

    type_str = ", ".join(sorted(wordtypes)) if wordtypes else ""
    summary = f"{found_word}" + (f" ({type_str})" if type_str else "") + f": {definitions[0]}"

    return {
        "found": True,
        "word": found_word,
        "original_query": query_text.strip(),
        "wordtype": type_str,
        "definitions": definitions[:8],
        "summary": summary
    }

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"found": False, "error": "Missing word argument"}))
        sys.exit(1)

    query = " ".join(sys.argv[1:])
    result = lookup(query)
    print(json.dumps(result))

if __name__ == "__main__":
    main()
