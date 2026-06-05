# Han Solo Connector

A Claude Code plugin that connects a machine to the Han Solo framework:

- **Always-on context** — injects the framework output contract on every message.
- **Phase skills** — when you're inside a framework project, injects the current
  phase's skill. Cloud-first (live from the Han Solo server), with a local
  framework clone as fallback when the server is unreachable.
- **The Han Solo server** — registers Ren, T4, and all the tools over MCP, with
  per-user identity via a bearer token.

The plugin carries **no secrets**. Your identity comes from one environment
variable, `HAN_SOLO_TOKEN`, so the same public plugin works for every teammate.

---

## What's in it

| File | Purpose |
|------|---------|
| `.claude-plugin/plugin.json` | Plugin manifest |
| `.claude-plugin/marketplace.json` | Marketplace index |
| `hooks/hooks.json` | Registers the always-on hook |
| `scripts/framework-skill-inject.sh` | The hook (bash, WSL2-safe) |
| `framework-always-on.md` | Bundled always-on context |
| `.mcp.json` | Han Solo server registration |

---

## Install (Windows + WSL2)

### Part 1 — One-time setup (manual)

These two things have to happen before the automated part:

1. **Get your Han Solo token.** Scott gives you your personal token value. Keep
   it handy for Step 1 below — it's how the server knows it's you.
2. **GitHub access to the framework.** Scott grants your GitHub account read
   access to `scoots31/framework-vers1` (it's private). Make sure your WSL can
   reach GitHub — either `gh auth login`, or an SSH key added to your account.

### Part 2 — Paste into Claude Code

Open Claude Code **inside your WSL shell** and paste the block below. Claude runs
each step and confirms before moving on.

```
Set up the Han Solo connector on my machine. I'm on Windows + WSL2 (Ubuntu),
bash shell. I'm a collaborator on the framework. Run each step in order, confirm
it worked before the next, and stop to ask me only if something needs my input.

Step 1 — My Han Solo token
Ask me for my Han Solo token, then add it to my shell profile so it's available
every session:
  echo 'export HAN_SOLO_TOKEN="<the token I give you>"' >> ~/.bashrc
Reload it: source ~/.bashrc
Verify: echo $HAN_SOLO_TOKEN  (should print the token)

Step 2 — Clone the framework (used as the offline fallback)
  mkdir -p ~/Developer
  cd ~/Developer
  git clone git@github.com:scoots31/framework-vers1.git "Framework Vers1"
(If SSH fails, use: gh repo clone scoots31/framework-vers1 "Framework Vers1")
Verify the folder ~/Developer/Framework Vers1/skills/ exists.

Step 3 — Write my CLAUDE.md
Create ~/.claude/CLAUDE.md with the "Working with Ted" content Scott provides
(separate file). This replaces my old engineering-playbook version.

Step 4 — Confirm prerequisites, then hand back to me for the plugin
Verify: git --version, python3 --version, node --version, and that
~/.claude/CLAUDE.md and ~/Developer/Framework Vers1/skills/ both exist.
Then tell me: "Prerequisites ready — now run the two /plugin commands in Step 5."
```

### Step 5 — Install the plugin (you type these yourself)

Plugin commands are typed directly into Claude Code, not run by Claude. In the
Claude Code prompt:

```
/plugin marketplace add scoots31/han-solo-plugin
/plugin install han-solo-connector@han-solo
```

Then **restart Claude Code** so the hook and the server load with your token in
the environment.

### Step 6 — Verify it's actually working

Start a new Claude Code session in WSL and check:

1. The Han Solo tools are available (the assistant can list Han Solo MCP tools).
2. Identity is correct — the server reports you as yourself, not a stranger.
3. The hook fired — check the debug log:
   ```
   cat ~/.claude/hook-debug.log
   ```
   It should show a line like `always-on:yes ...`. If the file is missing or
   says `always-on:no`, the hook did not run — stop and report it.

---

## Updating

When the connector changes, update in place — no reinstall:

```
/plugin update han-solo-connector
```

## Notes

- The plugin is public and contains no credentials. Your token lives only in
  your shell environment.
- Claude Code must be launched from a WSL shell where `HAN_SOLO_TOKEN` is
  exported (Step 1 puts it in `~/.bashrc`), so both the hook and the server can
  read it.
