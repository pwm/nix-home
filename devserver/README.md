---
title: "Agentic dev server playbook"
date: 2026-10-22
tags: [server, migration, agents, nix]
---

# Moving agent work to a new Linux server

This folder sets up a new Ubuntu 24.04 server for work with coding agents and
moves that work there from the old machine: the checkouts' unpublished
branches and worktrees, and the conversations, memory and settings of Claude
Code, Codex and OMP. Each step is a script you run in order. Logins, keys and
sign-ins stay manual.

A project add-on supplies what is particular to one project: its repositories,
build, MCP servers and checks. `pml/` is the add-on for PML; follow its
README beside this one.

It is the procedure of a move from a Mac to a Linux server on 2026-10-22, made
reusable. That move is the only real run. A move from one Linux server to
another (the same home path) is not tested yet; the scripts skip every path
rewrite when the two home folders are equal.

## Before you start

1. Order the server with Ubuntu 24.04 LTS and your SSH key for root.
2. On the old machine, copy `devserver/config.example.env` to
   `~/.config/devserver.env` and fill it in. It holds no secrets. `PROJECTS`
   lists the checkouts to move, relative to the home folder.
3. In the old machine's `~/.ssh/config`, add an alias for root and one for the
   account. The connection helper `bin/pml-dev` reaches the alias in
   `DEVSERVER_HOST` (default `pml-dev`).
4. Accept the server's host key once: `ssh root@ADDRESS true`.

Run the commands below from this nix-home checkout on the old machine.
`devserver/run-on.sh DESTINATION FILE...` sends your settings and the given
files, in order, as one script and runs it there: settings files (`.env`) and
function libraries first, the script last. The examples use `devbox` for the
account alias and `devbox-root` for root.

## 1. The server, as root

```bash
devserver/run-on.sh root@ADDRESS devserver/server/bootstrap-root.sh   # hostname, packages, account, Nix
ssh devbox true                                                        # a key login as the account must work
devserver/run-on.sh devbox-root devserver/server/harden-ssh.sh         # then key-only SSH, with keepalive
```

`bootstrap-root.sh` makes the account a trusted Nix user, which is
root-equivalent through the Nix daemon.

## 2. The account

1. Give the server its own GitHub key and add the public key on GitHub:
   ```bash
   ssh devbox 'ssh-keygen -t ed25519 -N "" -C "$USER@$(hostname)" -f ~/.ssh/id_ed25519 && cat ~/.ssh/id_ed25519.pub'
   ssh devbox 'ssh -o StrictHostKeyChecking=accept-new -T git@github.com'
   ```
2. Install the headless profile:
   ```bash
   devserver/run-on.sh devbox devserver/user/bootstrap-user.sh
   ```
3. Clone each project with its add-on's settings, then run the add-on's own
   steps (builds, private key file, MCP servers):
   ```bash
   devserver/run-on.sh devbox ADDON/project.env devserver/user/clone-repo.sh
   ```
4. Log in on the server: `claude`, then `/login`; `codex login --device-auth`.
   OMP needs no login when it uses GLM through LiteLLM only.
5. Register the personal MCP servers (Mermaid, fff) and Codex's trust for each
   checkout:
   ```bash
   devserver/run-on.sh devbox devserver/user/mcp-lib.sh devserver/user/agents.sh
   ```
6. Start LiteLLM for OMP. Run the same command again after every reboot: it
   replaces the exited `litellm` session Zellij keeps, and refuses a running one.
   ```bash
   devserver/run-on.sh devbox devserver/user/litellm-session.sh
   ```

## 3. Move the work, on the old machine

Close the agent sessions to move, and finish or hand over running work.
Commit what you want to keep; uncommitted work does not move.

The scripts read `~/.config/devserver.env` themselves, so they run the same
from Fish or Bash, and each checks every project in `PROJECTS` before it
copies anything:

```bash
devserver/migrate/branches.sh   # unpublished branches by Git bundle, the checked-out branch fast-forwarded, worktrees recreated
devserver/migrate/claude.sh     # settings first, then conversations and memory; EXCLUDE="ID" leaves the running session out
devserver/migrate/codex.sh      # conversations, AGENTS.override.md, preferences; THREAD=ID moves one thread with its subagents
devserver/migrate/omp.sh        # sessions, settings, memory banks, the prompt history (merged)
```

Conversations, memory, sessions and memory banks are never overwritten: a copy
refuses when anything of the same name is there already, refuses JSON Lines
files that end in an incomplete line (an agent still writing), and compares
every file's SHA-256 on both machines afterwards. Settings are the exception:
Codex's `config.toml` and OMP's `config.yml` are replaced and OMP's prompt
history merged, each with a dated backup beside it. A worktree path that exists
already must be the same repository's worktree on the same branch and commit.
Move documentation repositories with Git: commit and push them on the old
machine, and pull on the server.

From then on the server's checkouts, docs and agent state are the ones you
write. The old machine keeps its copies as a fallback; do not edit them. If an
agent session ran these steps, leave it out with `EXCLUDE="ID"`, exit it at the
end, and copy it last from a plain terminal with `ONLY="ID" devserver/migrate/claude.sh`.

## 4. Check the result

- **The project's own checks**, as its add-on describes.
- **Resume one conversation per agent** in each checkout: `claude --resume ID`,
  `codex resume ID`, `omp --resume ID`. When the home folder changed, OMP
  resumes a copied session only interactively and offers to move it into the
  current project; accept it.
- **Laptop sleep.** Attach to a Zellij session on the server named `ticker`
  and run `while true; date -u +%T; sleep 30; end` (Fish). Close the laptop for
  ten minutes, then reattach: the lines carry on every 30 seconds through the
  sleep. End the session afterwards.

## What is not copied

| Left out                                                                                        | Why                                                                        |
| ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Logins: `~/.claude.json`, `~/.claude/.credentials.json`, `~/.codex/auth.json`, OMP's `agent.db` | Credentials; log in on the server instead                                  |
| Codex's SQLite databases                                                                        | Codex rebuilds them from the rollout files                                 |
| Codex's `[mcp_servers.*]` and `[projects.*]` sections                                           | They can hold a token and the old paths; the server's are registered there |
| Claude Code's worktree project folders                                                          | Claude Code refuses to resume a conversation that two project folders hold |
| OMP's `memories/--<path>--` folder, temporary banks, caches, native files                       | Regenerated from `agent.db`, or rebuilt on the new system                  |

## Known limits

- Conversations keep their old working directory inside. Claude Code and Codex
  resume them anyway; OMP needs the interactive move described above.
- `omp-bank-name.py` reproduces OMP 18.5.1's bank names for folder names made of
  lowercase letters, digits and `-`, and refuses other names; `omp.sh` then
  refuses to copy when the source has memory banks it cannot attribute.
- `omp.sh` moves only the default project memory bank. It checks OMP's
  `config.yml` first (`omp-settings.py`) and copies nothing when it selects
  another bank (`mnemopi.bank`, `mnemopi.dbPath`, other scoping), holds one of
  OMP 18.5.1's credential settings, or uses YAML beyond the simple subset the
  check reads (block mappings, one-line values, simple lists, comments). With
  `OMP_SETTINGS=skip` a file whose only problem is a credential stays behind,
  and you set those settings by hand.
- `codex.sh` refuses a `config.toml` that sets `mcp_servers` or `projects`
  through top-level dotted or inline keys rather than tables, and any merge whose
  parsed result is not exactly the destination's server and project tables plus
  this machine's other settings.
- The scripts that run on the server need the account's login shell to be Bash
  (`bootstrap-root.sh` creates it so).
- Earlier versions named two system files after PML (`52pml-no-automatic-reboot`,
  `00-pml.conf`); a rerun on such a server adds the `devserver` files beside them,
  with the same settings.
- No daily copy of the server's agent history back to a laptop exists yet.

## Files

| File                       | Runs on         | What it does                                                         |
| -------------------------- | --------------- | -------------------------------------------------------------------- |
| `config.example.env`       |                 | Personal settings, to copy to `~/.config/devserver.env`              |
| `run-on.sh`                | old machine     | Runs settings, libraries and a script on a server as one script      |
| `server/bootstrap-root.sh` | server, root    | Hostname, packages, no automatic reboot, account, lingering, Nix     |
| `server/harden-ssh.sh`     | server, root    | Key-only SSH, client keepalive                                       |
| `user/bootstrap-user.sh`   | server, account | nix-home and its headless Home Manager profile                       |
| `user/clone-repo.sh`       | server, account | A project's clone, its documentation clone and link, direnv          |
| `user/mcp-lib.sh`          | server, account | Functions that register MCP servers with Claude Code and Codex       |
| `user/agents.sh`           | server, account | Personal MCP servers, Codex's trust for each checkout                |
| `user/litellm-session.sh`  | server, account | LiteLLM for OMP in the Zellij session `litellm`                      |
| `migrate/lib.sh`           | old machine     | Shared copy and hash-check helpers                                   |
| `migrate/branches.sh`      | old machine     | Unpublished branches and worktrees of each checkout                  |
| `migrate/claude.sh`        | old machine     | Claude Code settings, conversations and memory of each checkout      |
| `migrate/codex.sh`         | old machine     | Codex conversations, instructions, preferences                       |
| `migrate/omp.sh`           | old machine     | OMP sessions and memory bank of each checkout, settings, history     |
| `migrate/omp-bank-name.py` | either          | OMP's memory bank name for a path                                    |
| `migrate/omp-settings.py`  | old machine     | Refuses OMP settings with credentials, a non-default bank or odd YAML |

`tests/devserver-check.sh` checks every script's syntax and shellcheck, and
runs the migration scripts for real against fake home folders on one machine,
twice: with `DEST_SSH` empty, and through a stand-in `ssh` that, like ssh, reads
its standard input unless given `-n`. It runs `run-on.sh`, `user/clone-repo.sh`,
`user/mcp-lib.sh`, `user/agents.sh` and `user/litellm-session.sh` with stand-in
commands. The server scripts themselves only run on a real server.
