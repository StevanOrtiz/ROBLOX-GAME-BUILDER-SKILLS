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

echo "Installed to $DEST"
echo "Next: in Claude Code run  /output-style ihaveadhd  (or set \"outputStyle\": \"ihaveadhd\" in $DEST/settings.json)"
echo "Then restart Claude Code."
