#!/bin/zsh
# UserPromptSubmit hook — DB-driven framework injection (SL-B1)
#
# Fires before every user message. All framework instruction content comes from
# the Han Solo Framework DB over HTTP — there is NO local instruction file and NO
# local fallback. The only local inputs are framework-config.json (url + token)
# and, for phase content, the framework marker file.
#
# Injection layers:
#   1. Always-on   — the framework output contract, fetched from the DB
#                    (project_slug='default', content_type='always-on') and
#                    injected UNCONDITIONALLY on every message, before any early
#                    exit. Factory/no-marker sessions still get it.
#   2. Phase       — marker-gated, BUILT-BUT-DORMANT until Workstream C. When the
#                    marker file ~/.claude/framework-active is present and
#                    non-empty, its CONTENTS are the project_slug; the hook then
#                    fetches that project's current-phase content and the phase
#                    skill from the DB. No marker (the normal/factory case) = no
#                    phase injection. There is no marker-SETTER yet (Workstream C),
#                    so in normal operation this branch never fires.
#
# Fail-loud, never local: if the DB is reachable but returns nothing for a phase
# fetch, the hook emits a VISIBLE notice rather than silently catting a local
# SKILL.md (the old Framework-Vers1 fallback is removed). If the DB is unreachable
# entirely (curl fails), it degrades to injecting nothing for that layer — never
# blocking the message.
#
# Shell: zsh. Token + url: framework-config.json (han_solo_url + han_solo_token).
# Debug log: ~/.claude/hook-debug.log — one line per run, overwrites each session.
# Exits 0 in ALL cases — never blocks message delivery.

CONFIG="$HOME/.claude/hooks/framework-config.json"
MARKER="$HOME/.claude/framework-active"
DEBUG_LOG="$HOME/.claude/hook-debug.log"

input=$(cat)

# --- Debug state init ---
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
debug_always_on="no"
debug_phase="none"
debug_phase_tier="none"

# --- Read url + token from framework-config.json ---
han_solo_url=""
han_solo_token=""
if [[ -f "$CONFIG" ]]; then
    han_solo_url=$(/usr/bin/python3 -c "
import sys, json
try:
    cfg = json.load(open(sys.argv[1]))
    print(cfg.get('han_solo_url', ''))
except Exception:
    print('')
" "$CONFIG" 2>/dev/null)

    han_solo_token=$(/usr/bin/python3 -c "
import sys, json
try:
    cfg = json.load(open(sys.argv[1]))
    print(cfg.get('han_solo_token', ''))
except Exception:
    print('')
" "$CONFIG" 2>/dev/null)
fi

# fetch_content <project_slug> <content_type> — echoes the DB content (may be empty
# on a miss or on DB-unreachable). curl -sf --max-time 5 so an unreachable server
# degrades to empty rather than hanging or erroring.
fetch_content() {
    local slug="$1" ctype="$2"
    if [[ -z "$han_solo_url" || -z "$han_solo_token" ]]; then
        return 0
    fi
    curl -sf --max-time 5 \
        -H "Authorization: Bearer $han_solo_token" \
        "$han_solo_url/api/framework/project-content?project_slug=$slug&content_type=$ctype" \
        | /usr/bin/python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('content', ''))
except Exception:
    print('')
" 2>/dev/null
}

# fetch_skill <slug> — echoes the phase-skill content from the skills endpoint.
fetch_skill() {
    local slug="$1"
    if [[ -z "$han_solo_url" || -z "$han_solo_token" ]]; then
        return 0
    fi
    curl -sf --max-time 5 \
        -H "Authorization: Bearer $han_solo_token" \
        "$han_solo_url/api/framework/skills/$slug" \
        | /usr/bin/python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('content', ''))
except Exception:
    print('')
" 2>/dev/null
}

# --- Always-on injection (UNCONDITIONAL, every message, before any early exit) ---
always_on=$(fetch_content "default" "always-on")
if [[ -n "$always_on" ]]; then
    echo "## FRAMEWORK — ALWAYS ON"
    echo ""
    echo "$always_on"
    echo ""
    echo "---"
    echo ""
    debug_always_on="yes"
fi

# --- Phase injection (marker-gated, dormant until Workstream C) ---
# The marker file's CONTENTS are the project_slug. Absent or empty marker = no
# phase injection (factory-safe). There is no marker-setter yet, so this branch is
# inert in normal operation.
if [[ -s "$MARKER" ]]; then
    project_slug=$(head -n1 "$MARKER" 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$project_slug" ]]; then
        phase_content=$(fetch_content "$project_slug" "current-phase")
        if [[ -n "$phase_content" ]]; then
            echo "## FRAMEWORK — CURRENT PHASE"
            echo ""
            echo "$phase_content"
            echo ""
            debug_phase="$project_slug"

            # The current-phase content names the active phase skill on its first
            # line (slug). Fetch and inject that skill from the DB; no local
            # fallback — fail loud on a miss.
            phase_skill_slug=$(echo "$phase_content" | head -n1 | tr -d '[:space:]')
            if [[ -n "$phase_skill_slug" ]]; then
                skill_content=$(fetch_skill "$phase_skill_slug")
                if [[ -n "$skill_content" ]]; then
                    echo "$skill_content"
                    echo ""
                    debug_phase_tier="db"
                else
                    # FAIL LOUD: DB reachable for current-phase but the phase skill
                    # did not resolve. Never silently serve a local file (removed).
                    echo "## FRAMEWORK — PHASE SKILL UNAVAILABLE"
                    echo ""
                    echo "Phase skill '$phase_skill_slug' could not be loaded from the Han Solo DB (project '$project_slug'). No local fallback exists. Resolve the DB/skill before relying on phase guidance."
                    echo ""
                    debug_phase_tier="db-fail-loud"
                fi
            fi
        else
            # Marker is set with a slug but the DB returned no current-phase content.
            # Fail loud rather than silently proceeding with no phase guidance.
            echo "## FRAMEWORK — CURRENT PHASE UNAVAILABLE"
            echo ""
            echo "Framework marker is active for project '$project_slug' but no current-phase content was returned by the Han Solo DB. No local fallback exists. Resolve the DB before relying on phase guidance."
            echo ""
            debug_phase="$project_slug"
            debug_phase_tier="db-fail-loud"
        fi
    fi
fi

echo "[$timestamp] always-on:$debug_always_on phase:$debug_phase phase_tier:$debug_phase_tier" > "$DEBUG_LOG"
exit 0
