#!/usr/bin/env bash
# Install the Roblox skills, the ihaveadhd output style and the always-on CLAUDE.md block.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
mkdir -p "$DEST/skills" "$DEST/output-styles"

cp -r "$SRC"/skills/* "$DEST/skills/"
cp "$SRC/output-styles/ihaveadhd.md" "$DEST/output-styles/"

CM="$DEST/CLAUDE.md"
touch "$CM"
# drop any previous copy of the block, then append the current one
awk '/<!-- roblox-skills:begin -->/{skip=1} !skip{print} /<!-- roblox-skills:end -->/{skip=0}' "$CM" > "$CM.tmp"
mv "$CM.tmp" "$CM"
{ echo; cat "$SRC/claude-md-block.md"; } >> "$CM"

# set the global output style only if the user has not set one
SETTINGS="$DEST/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
python3 - "$SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
if "outputStyle" not in data:
    data["outputStyle"] = "ihaveadhd"
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print("outputStyle set to ihaveadhd")
else:
    print("outputStyle already set to", data["outputStyle"], "- left unchanged")
PY

echo "Installed to $DEST"
echo "Restart Claude Code to load the skills and the output style."
