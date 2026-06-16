#!/usr/bin/env bash
# A -> B sync: export forge* skills from source-of-truth (~/src/forge) to marketplace.
# One-way. Real files. Normalizes machine-specific paths. See B's forge/AGENTS.md.
set -euo pipefail
A=~/src/forge/skills
B=~/src/claude-marketplace/plugins/team-sdks/skills

SKILLS="forge forge-autopilot forge-design-creation forge-documentation \
forge-implement forge-implement-tests forge-implementation-planning \
forge-migrate forge-requirement-analysis forge-review forge-test-planning"

for s in $SKILLS; do
  rm -rf "$B/$s"
  cp -R "$A/$s" "$B/$s"
done

# Normalize machine-specific absolute paths in committed files.
find $(for s in $SKILLS; do echo "$B/$s"; done) -name '*.md' -print0 \
  | xargs -0 perl -0pi -e 's{/Users/[A-Za-z0-9._-]+/src/forge/}{}g; s{/Users/[A-Za-z0-9._-]+/}{/path/to/}g'

echo "=== sync verify: A vs B (normalized) ==="
norm(){ grep -vE '^(license:|metadata:|  author:)' "$1" | sed -E 's#/Users/[^ )]*/##g; s#/path/to/[^ )]*/##g'; }
for s in $SKILLS; do
  if diff -q "$A/$s/SKILL.md" "$B/$s/SKILL.md" >/dev/null 2>&1; then echo "  EXACT $s"; else
    d=$(diff <(norm "$A/$s/SKILL.md") <(norm "$B/$s/SKILL.md")|grep -c '^[<>]' || true); echo "  norm-diff=$d $s"; fi
done
echo "=== new files check (verification-protocol) ==="
ls "$B/forge/references/verification-protocol.md" && echo "  protocol synced"
echo "=== leak check ==="; grep -rl '/Users/' $(for s in $SKILLS; do echo "$B/$s"; done) 2>/dev/null || echo "  no /Users/ leaks"
