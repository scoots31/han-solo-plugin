# Han Solo Connector

A Claude Code plugin that connects a machine to the Han Solo framework:

- **Always-on context** — fetches the framework output contract from the Han Solo
  Framework DB and injects it on every message. There is no bundled file and no
  local fallback — the DB is the single source of truth.
- **Phase content** — when a framework project is active (signalled by the
  framework marker file), injects that project's current-phase content and phase
  skill, fetched live from the DB. Fail-loud: if the DB can't serve it, the hook
  says so rather than silently falling back to a local file.
- **The Han Solo server** — registers Ren, T4, and all the tools over MCP, with
  per-user identity via a bearer token.

The plugin carries **no secrets**. Your identity comes from a bearer token in
`framework-config.json`, so the same public plugin works for every teammate.

---

## What's in it

| File | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin manifest |
| `.claude-plugin/marketplace.json` | Marketplace index |
| `hooks/hooks.json` | Registers the always-on hook (invoked with zsh) |
| `scripts/framework-skill-inject.sh` | The hook (zsh, DB-driven) |
| `scripts/install.sh` | Reconciles a direct-invocation hook dir from the plugin |
| `.mcp.json` | Han Solo server registration |

All instruction content lives in the Framework DB. The only local inputs are
`framework-config.json` (the Han Solo url + your bearer token) and, for phase
content, the framework marker file `~/.claude/framework-active` (its contents are
the active project slug). The marker is session state, not an instruction file.

---

## Install (Windows + WSL2)

### Part 1 — One-time setup (manual)

Before the automated part:

1. **Get your Han Solo token.** Scott gives you your personal token value. Keep
   it handy for Step 1 below — it's how the server knows it's you.

No framework clone is needed any more — all instruction content comes from the
Framework DB at runtime, with no local fallback.

### Part 2 — Paste into Claude Code

Open Claude Code **inside your WSL shell** and paste the block below. Claude runs
each step and confirms before moving on.

```
Set up the Han Solo connector on my machine. I'm on Windows + WSL2 (Ubuntu).
I'm a collaborator on the framework. Run each step in order, confirm it worked
before the next, and stop to ask me only if something needs my input.

Step 1 — My Han Solo config (url + token)
Ask me for my Han Solo token, then write the connector config the hook reads:
  mkdir -p ~/.claude/hooks
  cat > ~/.claude/hooks/framework-config.json <<'EOF'
  {
    "han_solo_url": "https://han-solo-mcp.onrender.com",
    "han_solo_token": "<the token I give you>"
  }
  EOF
Verify: python3 -c "import json;print(json.load(open('$HOME/.claude/hooks/framework-config.json'))['han_solo_url'])"
(prints the url; the token stays in the file, never echoed).

Step 2 — Write my CLAUDE.md
Replace my old engineering-playbook version with the current "Working with Ted"
file from this repo:
  mkdir -p ~/.claude
  curl -fsSL https://raw.githubusercontent.com/scoots31/han-solo-plugin/main/working-with-ted.md -o ~/.claude/CLAUDE.md
Verify: head -1 ~/.claude/CLAUDE.md  (should read "# Working with Ted")

Step 3 — Remove MemPalace (retired)
It's no longer used. Uninstall the package and remove any leftover references:
  pip3 uninstall -y mempalace 2>/dev/null || true
(My new CLAUDE.md already has no MemPalace routing, so replacing it in Step 2
clears the rest.)

Step 4 — Confirm prerequisites, then hand back to me for the plugin
Verify: git --version, python3 --version, node --version, zsh --version, and that
~/.claude/CLAUDE.md and ~/.claude/hooks/framework-config.json both exist.
Then tell me: "Prerequisites ready — now run the two /plugin commands in Step 5."
```

### Step 5 — Install the plugin (you type these yourself)

Plugin commands are typed directly into Claude Code, not run by Claude. In the
Claude Code prompt:

```
/plugin marketplace add scoots31/han-solo-plugin
/plugin install han-solo-connector@han-solo
```

Then **restart Claude Code** so the hook and the server load.

### Step 6 — Verify it's actually working

Start a new Claude Code session in WSL and check:

1. The Han Solo tools are available (the assistant can list Han Solo MCP tools).
2. Identity is correct — the server reports you as yourself, not a stranger.
3. The hook fired — check the debug log:
   ```
   cat ~/.claude/hook-debug.log
   ```
   It should show a line like `always-on:yes ...`. If the file is missing or
   says `always-on:no`, the hook did not run — stop and report it. `always-on:no`
   with the hook running means the DB couldn't be reached or the token is wrong.

---

## Updating

For a plugin install, update in place — no reinstall:

```
/plugin update han-solo-connector
```

### Reinstall for direct-invocation machines

Some machines invoke the hook by absolute path from `~/.claude/settings.json`
rather than through the plugin's `hooks.json`. On those, the live copy in
`~/.claude/hooks` drifts from the plugin unless it is reconciled. After pulling a
new version of this repo, run the install script to copy the canonical hook and
`hooks.json` into `~/.claude/hooks`:

```
zsh scripts/install.sh
```

It overwrites the live hook script and `hooks.json` from the plugin; it does NOT
touch `framework-config.json` (your url + token) or `settings.json` (your
invocation wiring). Restart Claude Code afterward.

## Notes

- The plugin is public and contains no credentials. Your token lives only in
  `~/.claude/hooks/framework-config.json` on your machine.
- All framework instruction content is fetched from the Framework DB at runtime.
  There is no local instruction file and no offline fallback — if the DB can't be
  reached, the hook injects nothing for that layer (always-on) or says so loudly
  (phase content), and never blocks your message.
