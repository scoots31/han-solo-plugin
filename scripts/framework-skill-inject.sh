#!/bin/bash
# UserPromptSubmit hook — framework skill injection (plugin port)
#
# Fires before every user message. Injects two things:
#   1. Always-on  — output contract / framework context (unconditional)
#   2. Phase skill — full content of the current phase skill, when a project
#                    folder declares one (cloud-first, local-file fallback)
#
# This is the PLUGIN version of the connector. Differences from the original
# local hook:
#   - bash, not zsh (WSL2-safe)
#   - paths resolved via ${CLAUDE_PLUGIN_ROOT} (no hardcoded home dir)
#   - token read from $HAN_SOLO_TOKEN env var (no plaintext config file)
#   - Ren re-anchor block removed — collaborators talk to the real Ren via MCP
#
# Tier selection for phase skills (checked in order):
#   Cloud — han-solo server /api/skills/{slug} with $HAN_SOLO_TOKEN (5s timeout)
#   File  — $FRAMEWORK_DIR/skills/{slug}/SKILL.md (fallback)
#
# Debug log: ~/.claude/hook-debug.log — one line per run, overwrites each session.
# Exits 0 in all cases — never blocks message delivery.

ALWAYS_ON="${CLAUDE_PLUGIN_ROOT}/framework-always-on.md"
FRAMEWORK_DIR="${FRAMEWORK_DIR:-$HOME/Developer/Framework Vers1}"
HAN_SOLO_URL="https://han-solo-mcp.onrender.com"
DEBUG_LOG="$HOME/.claude/hook-debug.log"

input=$(cat)

# --- Debug state init ---
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
debug_always_on="no"
debug_phase="none"
debug_tier="none"

# Extract cwd from UserPromptSubmit input JSON
cwd=$(/usr/bin/python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('cwd', ''))
except Exception:
    print('')
" <<< "$input" 2>/dev/null)

# --- Always-on injection ---
if [[ -f "$ALWAYS_ON" ]]; then
    echo "## FRAMEWORK — ALWAYS ON"
    echo ""
    cat "$ALWAYS_ON"
    echo ""
    echo "---"
    echo ""
    debug_always_on="yes"
fi

# --- Phase-active injection ---
PHASE_FILE="$cwd/docs/continuity/current-phase.md"

if [[ -z "$cwd" || ! -f "$PHASE_FILE" ]]; then
    echo "[$timestamp] always-on:$debug_always_on phase:$debug_phase tier:$debug_tier" > "$DEBUG_LOG"
    exit 0
fi

# Extract phase name from "**Phase:** Design Review" pattern
phase_raw=$(/usr/bin/python3 -c "
import sys, re
try:
    content = open(sys.argv[1]).read()
    match = re.search(r'\*\*Phase:\*\*\s*(.+)', content)
    print(match.group(1).strip() if match else '')
except Exception:
    print('')
" "$PHASE_FILE" 2>/dev/null)

if [[ -z "$phase_raw" ]]; then
    echo "[$timestamp] always-on:$debug_always_on phase:$debug_phase tier:$debug_tier" > "$DEBUG_LOG"
    exit 0
fi

# Map phase display name to skill slug
skill_slug=$(/usr/bin/python3 -c "
import sys
phase = sys.argv[1].lower()
mapping = {
    'brainstorming': 'brainstorming',
    'brainstorm': 'brainstorming',
    'discover': 'discover',
    'discovery': 'discover',
    'tech context': 'tech-context',
    'design sprint': 'design-sprint',
    'data scaffold': 'data-scaffold',
    'design review': 'design-review',
    'prd to plan': 'prd-to-plan',
    'plan': 'prd-to-plan',
    'to issues': 'to-issues',
    'build': 'solo-build',
    'autopilot': 'autopilot',
    'qa': 'solo-qa',
    'phase test': 'phase-test',
    'deploy': 'deploy',
}
print(mapping.get(phase, ''))
" "$phase_raw" 2>/dev/null)

if [[ -z "$skill_slug" ]]; then
    echo "[$timestamp] always-on:$debug_always_on phase:$debug_phase tier:$debug_tier" > "$DEBUG_LOG"
    exit 0
fi

echo "## FRAMEWORK — ACTIVE PHASE: $phase_raw"
echo ""
debug_phase="$skill_slug"

# --- Tier selection: cloud first, then local file ---
if [[ -n "$HAN_SOLO_TOKEN" ]]; then
    skill_content=$(curl -sf --max-time 5 \
        -H "Authorization: Bearer $HAN_SOLO_TOKEN" \
        "$HAN_SOLO_URL/api/skills/$skill_slug" \
        | /usr/bin/python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('content', ''))
except Exception:
    print('')
" 2>/dev/null)

    if [[ -n "$skill_content" ]]; then
        echo "$skill_content"
        echo ""
        debug_tier="cloud"
        echo "[$timestamp] always-on:$debug_always_on phase:$debug_phase tier:$debug_tier" > "$DEBUG_LOG"
        exit 0
    fi
    debug_tier="cloud-failed"
fi

# File tier fallback
SKILL_FILE="$FRAMEWORK_DIR/skills/$skill_slug/SKILL.md"

if [[ -f "$SKILL_FILE" ]]; then
    cat "$SKILL_FILE"
    echo ""
    debug_tier="file"
fi

echo "[$timestamp] always-on:$debug_always_on phase:$debug_phase tier:$debug_tier" > "$DEBUG_LOG"
exit 0
