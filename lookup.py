#!/usr/bin/env python3
"""
High-speed offline dictionary query engine for Noctalia Dictionary Plugin.
Ships with Webster's 1913 dictionary compressed via xz (data/webster1913.sqlite.xz).
Auto-decompresses into ~/.cache/noctalia-dictionary/ on first run.

Features:
- Candidate morphology rules (plurals, -ing, -ed, -ly, -er, -est, etc.)
- Progressive prefix backoff suggestions when an exact match is missing
- Direct wl-copy clipboard integration (no shell escaping issues)
- Sub-millisecond indexed SQLite queries
"""

import sys
import os
import re
import json
import lzma
import sqlite3
import subprocess

CACHE_DIR = os.path.expanduser("~/.cache/noctalia-dictionary")
RUNTIME_DB = os.path.join(CACHE_DIR, "webster1913.sqlite")
PLUGIN_DIR = os.path.dirname(os.path.abspath(__file__))
COMPRESSED_SRC = os.path.join(PLUGIN_DIR, "data", "webster1913.sqlite.xz")
LOCAL_UNCOMPRESSED = os.path.expanduser("~/.local/share/noctalia/dictionary/dictionary.db")

def ensure_database():
    """Ensure the uncompressed SQLite database is ready in the cache directory."""
    if os.path.isfile(RUNTIME_DB):
        return RUNTIME_DB

    # Check if local share already has it
    if os.path.isfile(LOCAL_UNCOMPRESSED):
        return LOCAL_UNCOMPRESSED

    if not os.path.isfile(COMPRESSED_SRC):
        return None

    os.makedirs(CACHE_DIR, exist_ok=True)
    tmp_path = RUNTIME_DB + ".tmp"
    try:
        with lzma.open(COMPRESSED_SRC, "rb") as f_in, open(tmp_path, "wb") as f_out:
            while True:
                chunk = f_in.read(1024 * 1024)
                if not chunk:
                    break
                f_out.write(chunk)
        os.replace(tmp_path, RUNTIME_DB)
        return RUNTIME_DB
    except Exception:
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass
        return None

def normalize_query(raw):
    # Cap to 400 characters, normalize whitespace, lowercase
    s = raw[:400]
    s = s.replace("\n", " ").replace("\t", " ")
    s = re.sub(r"[^a-zA-Z0-9'’\s-]", " ", s)
    s = re.sub(r"\s+", " ", s).strip().lower()
    return s

def build_candidates(norm_query):
    """
    Build ordered candidates: full phrase, first word,
    and light morphology rules (from omarchy-lookup / GCIDE).
    """
    cands = []
    seen = set()

    def add(c):
        if c and c not in seen:
            seen.add(c)
            cands.append(c)

    add(norm_query)

    first = norm_query.split()[0] if " " in norm_query else norm_query
    add(first)

    w = first
    # -ies -> -y
    if w.endswith("ies") and len(w) > 4:
        add(w[:-3] + "y")
    # -sses, -shes, -ches, -xes, -zes -> -es
    for suffix in ("sses", "shes", "ches", "xes", "zes"):
        if w.endswith(suffix) and len(w) > len(suffix):
            add(w[:-2])
    # -es -> -s, -
    if w.endswith("es") and len(w) > 3:
        add(w[:-1])
        add(w[:-2])
    # -s -> -
    if w.endswith("s") and len(w) > 2 and not w.endswith("ss"):
        add(w[:-1])
    # -ing -> -, -e
    if w.endswith("ing") and len(w) > 4:
        add(w[:-3])
        add(w[:-3] + "e")
        if len(word_end := w[:-3]) and len(word_end) > 1 and word_end[-1] == word_end[-2]:
            add(word_end[:-1])
    # -ed -> -, -d, -e
    if w.endswith("ed") and len(w) > 3:
        add(w[:-2])
        add(w[:-1])
        add(w[:-2] + "e")
    # -ly -> -
    if w.endswith("ly") and len(w) > 4:
        add(w[:-2])
        add(w[:-2] + "le")
    # -er -> -, -e
    if w.endswith("er") and len(w) > 4:
        add(w[:-2])
        add(w[:-1])
    # -est -> -
    if w.endswith("est") and len(w) > 5:
        add(w[:-3])
        add(w[:-2])

    return first, cands

def progressive_suggestions(cursor, word):
    """
    Progressive prefix backoff: if word misses, shorten the prefix
    from length n down to 4 characters until matching suggestions are found.
    """
    n = len(word)
    for p in range(n, 3, -1):
        prefix = word[:p]
        cursor.execute(
            "SELECT DISTINCT word FROM entries WHERE word LIKE ? ORDER BY length(word), word LIMIT 8",
            (prefix + "%",)
        )
        suggs = [r[0] for r in cursor.fetchall()]
        if suggs:
            return suggs
    return []

def query_database(raw_query):
    norm = normalize_query(raw_query)
    if not norm:
        return {
            "query": raw_query,
            "word": "",
            "found": False,
            "definitions": [],
            "suggestions": [],
            "error": "Empty search query"
        }

    first_word, candidates = build_candidates(norm)

    db_path = ensure_database()
    if not db_path:
        return {
            "query": raw_query,
            "word": first_word,
            "found": False,
            "definitions": [],
            "suggestions": [],
            "error": "Database not found or could not decompress"
        }

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    found_word = None
    rows = []

    for cand in candidates:
        cursor.execute(
            "SELECT word, wordtype, definition FROM entries WHERE word = ? COLLATE NOCASE LIMIT 12",
            (cand,)
        )
        results = cursor.fetchall()
        if results:
            found_word = cand
            rows = results
            break

    if not rows:
        # Exact word missed: run progressive prefix backoff
        suggestions = progressive_suggestions(cursor, first_word)
        conn.close()
        return {
            "query": raw_query,
            "word": first_word,
            "found": False,
            "definitions": [],
            "suggestions": suggestions,
            "error": f"No definition found for '{first_word}'"
        }

    conn.close()

    definitions = []
    wordtypes = set()

    for w, wt, d in rows:
        if wt and wt.strip():
            wordtypes.add(wt.strip())
        clean_d = re.sub(r"\s+", " ", d.strip())
        definitions.append(clean_d)

    type_str = ", ".join(sorted(wordtypes)) if wordtypes else ""
    summary = f"{found_word}" + (f" ({type_str})" if type_str else "") + f": {definitions[0]}"

    return {
        "query": raw_query,
        "word": found_word,
        "found": True,
        "wordtype": type_str,
        "definitions": definitions[:10],
        "summary": summary,
        "suggestions": []
    }

def copy_to_clipboard(text):
    try:
        subprocess.run(["wl-copy"], input=text.encode("utf-8"), check=True, timeout=2)
    except Exception:
        pass

def main():
    args = sys.argv[1:]
    if not args:
        print(json.dumps({"found": False, "error": "Missing word argument"}))
        sys.exit(1)

    should_copy = False
    if args[0] == "--copy":
        should_copy = True
        args = args[1:]

    query = " ".join(args)
    result = query_database(query)

    if should_copy and result.get("found") and result.get("summary"):
        copy_to_clipboard(result["summary"])

    print(json.dumps(result))

if __name__ == "__main__":
    main()
