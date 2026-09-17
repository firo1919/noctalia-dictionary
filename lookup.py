#!/usr/bin/env python3
"""
Lightweight offline English dictionary lookup engine for Noctalia.
Supports:
1. Local SQLite Database (176,000+ words with lemmatization, zero dependencies)
2. sdcv (StarDict Console Version, if installed with dictionaries)
3. dict (DICT client, if installed)
"""

import sys
import os
import re
import json
import shutil
import sqlite3
import subprocess

DEFAULT_DB_PATH = os.path.expanduser("~/.local/share/noctalia/dictionary/dictionary.db")
LOCAL_DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dictionary.db")

def clean_word(raw):
    s = raw.strip()
    s = re.sub(r"^[^a-zA-Z]+|[^a-zA-Z]+$", "", s)
    return s.strip().lower()

def lookup_sdcv(word):
    """Query local StarDict dictionaries via sdcv if installed."""
    if not shutil.which("sdcv"):
        return None

    try:
        res = subprocess.run(
            ["sdcv", "-n", "--utf8-output", word],
            capture_output=True,
            text=True,
            timeout=3
        )
        out = res.stdout.strip()
        if not out or "Nothing similar to" in out or "No dictionaries found" in out:
            return None

        lines = out.splitlines()
        clean_lines = []
        for line in lines:
            if line.startswith("-->"):
                continue
            l = line.strip()
            if l:
                clean_lines.append(l)

        if clean_lines:
            defs = clean_lines[:6]
            return {
                "found": True,
                "word": word,
                "backend": "sdcv",
                "wordtype": "",
                "definitions": defs,
                "summary": f"{word}: {defs[0]}"
            }
    except Exception:
        pass
    return None

def lookup_dict_cli(word):
    """Query dict client if installed."""
    if not shutil.which("dict"):
        return None

    try:
        res = subprocess.run(
            ["dict", "-d", "all", word],
            capture_output=True,
            text=True,
            timeout=3
        )
        out = res.stdout.strip()
        if not out or "No definitions found" in out or "could not connect" in out:
            return None

        lines = [l.strip() for l in out.splitlines() if l.strip() and not l.startswith("From ")]
        if lines:
            defs = lines[:6]
            return {
                "found": True,
                "word": word,
                "backend": "dict",
                "wordtype": "",
                "definitions": defs,
                "summary": f"{word}: {defs[0]}"
            }
    except Exception:
        pass
    return None

def lemmatize(word):
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
        if len(word) > 5 and word[-4] == word[-5]:
            candidates.append(word[:-4])
    if word.endswith("ly") and len(word) > 3:
        candidates.append(word[:-2])
        candidates.append(word[:-2] + "le")
    return candidates

def lookup_sqlite_single(word):
    db_path = None
    if os.path.isfile(DEFAULT_DB_PATH):
        db_path = DEFAULT_DB_PATH
    elif os.path.isfile(LOCAL_DB_PATH):
        db_path = LOCAL_DB_PATH

    if not db_path:
        return None

    try:
        conn = sqlite3.connect(db_path)
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
            "backend": "sqlite",
            "wordtype": type_str,
            "definitions": definitions[:8],
            "summary": summary
        }
    except Exception as e:
        return {
            "found": False,
            "word": word,
            "error": str(e)
        }

def lookup_query(raw_query):
    # Try exact / full cleaned word first
    clean = clean_word(raw_query)
    if not clean:
        return {"found": False, "word": raw_query, "error": "No valid word selected"}

    # 1. Try SDCV
    res = lookup_sdcv(clean)
    if res and res.get("found"):
        return res

    # 2. Try dict CLI
    res = lookup_dict_cli(clean)
    if res and res.get("found"):
        return res

    # 3. Try SQLite
    res = lookup_sqlite_single(clean)
    if res and res.get("found"):
        return res

    # 4. If query had multiple words, try first word as fallback
    words = raw_query.strip().split()
    if len(words) > 1:
        first = clean_word(words[0])
        if first and first != clean:
            first_res = lookup_query(first)
            if first_res and first_res.get("found"):
                return first_res

    # Return suggestions from the original single lookup if available
    if res:
        return res

    return {
        "found": False,
        "word": clean,
        "error": f"No definition found for '{clean}'"
    }

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"found": False, "error": "Missing word argument"}))
        sys.exit(1)

    query = " ".join(sys.argv[1:])
    result = lookup_query(query)
    print(json.dumps(result))

if __name__ == "__main__":
    main()
