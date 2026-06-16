#!/usr/bin/env bash
set -euo pipefail
cd ~/src/forge
B=~/src/claude-marketplace/plugins/team-sdks/skills

git config commit.gpgsign false

# fresh branch from current main (4d3844a + nothing outer-tracked changed)
git branch -D reconcile-layout 2>/dev/null || true
git checkout -q -b reconcile-layout

# 1. move flat refs -> references/
mkdir -p skills/forge/references
for f in cascade-detector forge-logs-generator git-hardening state-schema task-agent-prompt-template; do
  git mv "skills/forge/$f.md" "skills/forge/references/$f.md"
done

# 2. rewrite link paths ./X -> ./references/X in forge/SKILL.md
perl -0pi -e 's{\]\(\./(cascade-detector|forge-logs-generator|git-hardening|state-schema|task-agent-prompt-template)\.md\)}{](./references/$1.md)}g' skills/forge/SKILL.md

# 3. add metadata header (after name+description lines) if absent
if ! grep -q '^license:' skills/forge/SKILL.md; then
  perl -0pi -e 's{(^---\nname: forge\ndescription: [^\n]*\n)}{$1license: Proprietary\nmetadata:\n  author: Auth0 SDKs Team <sdks\@auth0.com>\n}m' skills/forge/SKILL.md
fi

git add -A
git commit -q -m "refactor: adopt references/ layout to match marketplace"

echo "============================================================"
echo "DIFF 1: reconcile-layout forge/SKILL.md  vs  B forge/SKILL.md"
echo "============================================================"
diff skills/forge/SKILL.md "$B/forge/SKILL.md" && echo "  IDENTICAL"

echo "============================================================"
echo "DIFF 2: references/ dir listing  A vs B"
echo "============================================================"
diff <(ls skills/forge/references/) <(ls "$B/forge/references/") && echo "  SAME FILE SET"

echo "============================================================"
echo "DIFF 3: each reference file  A vs B"
echo "============================================================"
for f in skills/forge/references/*.md; do
  bn=$(basename "$f")
  if diff -q "$f" "$B/forge/references/$bn" >/dev/null 2>&1; then
    echo "  OK  $bn"
  else
    echo "  DIFF $bn :"; diff "$f" "$B/forge/references/$bn" | head -20
  fi
done

echo "============================================================"
echo "DIFF 4: all forge-* skills (A reconcile vs B), SKILL.md only"
echo "============================================================"
for d in skills/forge*/; do
  s=$(basename "$d")
  if [ -f "$d/SKILL.md" ] && [ -f "$B/$s/SKILL.md" ]; then
    if diff -q "$d/SKILL.md" "$B/$s/SKILL.md" >/dev/null 2>&1; then echo "  OK   $s"; else echo "  DIFF $s ($(diff "$d/SKILL.md" "$B/$s/SKILL.md" | grep -c '^[<>]') lines)"; fi
  else
    echo "  MISSING-one-side $s"
  fi
done
