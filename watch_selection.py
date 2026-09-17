#!/usr/bin/env python3
"""
Waits for the user to highlight text with their mouse on Wayland.
Polls wl-paste --primary --no-newline every 150ms until the selection changes.
Times out after 20 seconds.
"""

import sys
import time
import subprocess

def get_primary():
    try:
        res = subprocess.run(
            ["wl-paste", "-p", "-n"],
            capture_output=True,
            text=True,
            timeout=2
        )
        return res.stdout.strip()
    except Exception:
        return ""

def main():
    timeout = 20.0
    if len(sys.argv) > 1:
        try:
            timeout = float(sys.argv[1])
        except ValueError:
            pass

    initial = get_primary()
    start = time.time()

    while time.time() - start < timeout:
        time.sleep(0.15)
        current = get_primary()
        if current and current != initial:
            # New text has been selected!
            print(current)
            sys.exit(0)

    # Timeout
    sys.exit(1)

if __name__ == "__main__":
    main()
