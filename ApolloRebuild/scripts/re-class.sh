#!/bin/bash
# re-class.sh - list every recovered name for a class (or substring), the way
# per-screen investigations need it.
#
#   ./scripts/re-class.sh PostsViewController
#   ./scripts/re-class.sh PostsViewController --files     # also print file paths
#
# Names come from ~/Projects/Apollo-Source-Private/naming/name-map.json, which
# maps function address -> recovered name (ObjC selectors + Swift debug strings).

set -eu
ROOT="$HOME/Projects/Apollo-Source-Private"
PATTERN="${1:?usage: re-class.sh <ClassOrSubstring> [--files]}"
SHOW_FILES="${2:-}"

python3 - "$ROOT" "$PATTERN" "$SHOW_FILES" <<'PY'
import json, sys, os, re
root, pattern, show_files = sys.argv[1], sys.argv[2], sys.argv[3]
m = json.load(open(os.path.join(root, 'naming/name-map.json')))
hits = {}
for addr, info in m.items():
    name = info.get('name', '')
    if pattern.lower() in name.lower():
        hits.setdefault(name, []).append(addr)
for name in sorted(hits):
    if show_files:
        for a in sorted(hits[name]):
            print(f'{a}  {name}')
    else:
        print(name)
PY
