#!/bin/zsh
# install.sh — reconcile the live ~/.claude/hooks dir FROM this plugin (SL-B1).
#
# The plugin is the CANONICAL source of the framework hook. Two ways the hook can
# run on a machine:
#   - Plugin path (Ted / collaborators): `/plugin install` wires hooks.json, which
#     invokes scripts/framework-skill-inject.sh from ${CLAUDE_PLUGIN_ROOT}. No copy
#     needed — the plugin IS the live copy.
#   - Direct path (Scott's box today): ~/.claude/settings.json invokes
#     ~/.claude/hooks/framework-skill-inject.sh by absolute path. That live copy
#     drifts from the plugin unless it is reinstalled. THIS script reconciles it:
#     it copies the canonical hook script + hooks.json from the plugin into
#     ~/.claude/hooks, so the directly-invoked copy matches the plugin exactly.
#
# Idempotent: re-running overwrites the live copies with the plugin's current
# versions. It does NOT touch framework-config.json (the machine's url+token) and
# does NOT modify ~/.claude/settings.json (the invocation wiring is the user's).
#
# Run from anywhere:  zsh scripts/install.sh   (or ./scripts/install.sh)

set -e

# Resolve the plugin root as the parent of this script's directory, so the script
# works regardless of cwd or where the plugin is checked out.
SCRIPT_DIR="${0:A:h}"
PLUGIN_ROOT="${SCRIPT_DIR:h}"
HOOKS_DIR="$HOME/.claude/hooks"

mkdir -p "$HOOKS_DIR"

cp "$PLUGIN_ROOT/scripts/framework-skill-inject.sh" "$HOOKS_DIR/framework-skill-inject.sh"
chmod +x "$HOOKS_DIR/framework-skill-inject.sh"
cp "$PLUGIN_ROOT/hooks/hooks.json" "$HOOKS_DIR/hooks.json"

echo "Reconciled live hook dir from plugin:"
echo "  $HOOKS_DIR/framework-skill-inject.sh"
echo "  $HOOKS_DIR/hooks.json"
echo ""
echo "framework-config.json (url + token) and ~/.claude/settings.json were NOT touched."
echo "If this machine invokes the hook via settings.json by absolute path, it now"
echo "runs the canonical plugin version. Restart Claude Code to pick up the change."
