---
title: "PML server playbook"
date: 2026-10-22
tags: [pml, server, migration, agents]
---

# Moving PML work to a new Linux server

This folder sets up a new Ubuntu 24.04 server for PML work and moves the work
there from the old machine: the checkout's unpublished branches and worktrees,
and the conversations, memory and settings of Claude Code, Codex and OMP. Each
step is a script you run in order. Logins, keys and sign-ins stay manual.

It is the procedure of the 2026-10-22 move from a Mac to `pml-dev`, made
reusable. That move is the only real run. A move from one Linux server to
another (the same `/home/pwm` paths) is not tested yet; the scripts skip every
path rewrite when the two home folders are equal.

## Before you start

1. Order the server with Ubuntu 24.04 LTS and your SSH key for root.
2. On the old machine, copy `pml/config.example.env` to
   `~/.config/pml-playbook.env` and fill it in. It holds no secrets.
3. In the old machine's `~/.ssh/config`, add an alias for root and one for the
   account (see `remote-dev.md` in PML for the current ones). Keep the account
   alias named `pml-dev` if you want the `pml-dev` helper to reach the new server.
4. Accept the server's host key once: `ssh root@ADDRESS true`.

Run the commands below from this nix-home checkout on the old machine.
`pml/run-on.sh DESTINATION SCRIPT` runs a script there with your settings.

## 1. The server, as root

```bash
pml/run-on.sh root@ADDRESS pml/server/bootstrap-root.sh   # hostname, packages, account, Nix
ssh pml-dev true                                           # a key login as the account must work
pml/run-on.sh pml-dev-root pml/server/harden-ssh.sh        # then key-only SSH, with keepalive
pml/run-on.sh pml-dev-root pml/server/playwright-deps.sh   # libraries for the browser checks
```

`bootstrap-root.sh` makes the account a trusted Nix user, which is
root-equivalent through the Nix daemon.

## 2. The account

1. Give the server its own GitHub key and add the public key on GitHub:
   ```bash
   ssh pml-dev 'ssh-keygen -t ed25519 -N "" -C "$USER@$(hostname)" -f ~/.ssh/id_ed25519 && cat ~/.ssh/id_ed25519.pub'
   ssh pml-dev 'ssh -o StrictHostKeyChecking=accept-new -T git@github.com'
   ```
2. Install the headless profile, then clone PML and the docs and build:
   ```bash
   pml/run-on.sh pml-dev pml/user/bootstrap-user.sh
   pml/run-on.sh pml-dev pml/user/clone-pml.sh
   ```
3. Create `~/work/pml/.envrc.private` (mode 600) by hand, or copy the old one:
   `scp ~/work/pml/.envrc.private pml-dev:work/pml/ && ssh pml-dev chmod 600 work/pml/.envrc.private`.
   It exports `ANTHROPIC_API_KEY` (PML's web chat), `MERMAID_API_KEY` (the
   Mermaid MCP server) and `ZAI_API_KEY` (OMP's GLM model). Never commit it.
4. Log in on the server: `claude`, then `/login`; `codex login --device-auth`.
   When Claude Code started under `~/work/pml` asks whether to use the
   `ANTHROPIC_API_KEY` it found, answer No, to keep the subscription login. OMP
   needs no login: it uses GLM only, through LiteLLM.
5. Register the MCP servers, then do the sign-ins the script prints:
   ```bash
   pml/run-on.sh pml-dev pml/user/agents.sh
   ```
6. Start LiteLLM for OMP. Run the same command again after every reboot: it
   replaces the exited `litellm` session Zellij keeps, and refuses a running one.
   ```bash
   pml/run-on.sh pml-dev pml/user/litellm-session.sh
   ```

## 3. Move the work, on the old machine

Close the agent sessions to move, and finish or hand over running PML runs.
Commit what you want to keep; uncommitted work does not move.

The scripts read `~/.config/pml-playbook.env` themselves, so they run the same
from Fish or Bash:

```bash
pml/migrate/branches.sh   # unpublished branches by Git bundle, the checked-out branch fast-forwarded, worktrees recreated
pml/migrate/claude.sh     # settings first, then conversations and memory; EXCLUDE="ID" leaves the running session out
pml/migrate/codex.sh      # conversations, AGENTS.override.md, preferences; THREAD=ID moves one thread with its subagents
pml/migrate/omp.sh        # sessions, settings, the memory bank, the prompt history (merged)
```

Conversations, memory, sessions and memory banks are never overwritten: a copy
refuses when anything of the same name is there already, refuses JSON Lines
files that end in an incomplete line (an agent still writing), and compares
every file's SHA-256 on both machines afterwards. Settings are the exception:
Codex's `config.toml` and OMP's `config.yml` are replaced and OMP's prompt
history merged, each with a dated backup beside it. A worktree path that exists
already must be the same repository's worktree on the same branch and commit. Then move the docs with Git: commit and push them
on the old machine, and `git -C ~/work/docs/pml pull --ff-only` on the server.

From then on the server's checkout, docs and agent state are the ones you
write. The old machine keeps its copies as a fallback; do not edit them. If an
agent session ran these steps, leave it out with `EXCLUDE="ID"`, exit it at the
end, and copy it last from a plain terminal with `ONLY="ID" pml/migrate/claude.sh`.

## 4. Check the result

- **Gate chains.** On the server, in a worktree prepared with
  `scripts/worktree.py`, run PML's native chains once (`scripts/gates/*.json`,
  as PML's `AGENTS.md` describes). The container chain and the ARM64 release
  need an ARM64 machine and stay on the Mac.
- **Resume one conversation per agent** from `~/work/pml`: `claude --resume ID`,
  `codex resume ID`, `omp --resume ID`. When the home folder changed, OMP
  resumes a copied session only interactively and offers to move it into the
  current project; accept it.
- **Laptop sleep.** In `pml-dev attach ticker`, run
  `while true; date -u +%T; sleep 30; end` (Fish). Close the laptop for ten
  minutes, then reattach: the lines carry on every 30 seconds through the sleep.
  End the session afterwards.
- **MCP.** In each agent, list the PML records through `pml`, and through
  `pml-local` while `scripts/local.sh` runs.

## What is not copied

| Left out                                                                                        | Why                                                                        |
| ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Logins: `~/.claude.json`, `~/.claude/.credentials.json`, `~/.codex/auth.json`, OMP's `agent.db` | Credentials; log in on the server instead                                  |
| Codex's SQLite databases                                                                        | Codex rebuilds them from the rollout files                                 |
| Codex's `[mcp_servers.*]` and `[projects.*]` sections                                           | They can hold a token and the old paths; `agents.sh` writes the server's   |
| Claude Code's worktree project folders                                                          | Claude Code refuses to resume a conversation that two project folders hold |
| OMP's `memories/--<path>--` folder, temporary banks, caches, native files                       | Regenerated from `agent.db`, or rebuilt on the new system                  |

## Known limits

- Conversations keep their old working directory inside. Claude Code and Codex
  resume them anyway; OMP needs the interactive move described above.
- `omp-bank-name.py` reproduces OMP 18.5.1's bank names for folder names made of
  lowercase letters, digits and `-`, such as `pml`, and refuses other names.
- `omp.sh` moves only the default project memory bank. It checks OMP's
  `config.yml` first (`omp-settings.py`) and copies nothing when it selects
  another bank (`mnemopi.bank`, `mnemopi.dbPath`, other scoping) or holds one of
  OMP 18.5.1's credential settings; with `OMP_SETTINGS=skip` the settings stay
  behind and you set them by hand.
- `codex.sh` refuses a `config.toml` that sets `mcp_servers` or `projects`
  through top-level dotted or inline keys rather than tables, and any merge whose
  parsed result is not exactly the destination's server and project tables plus
  this machine's other settings.
- The scripts that run on the server need the account's login shell to be Bash
  (`bootstrap-root.sh` creates it so).
- No daily copy of the server's agent history back to a laptop exists yet.

## Files

| File                        | Runs on         | What it does                                                     |
| --------------------------- | --------------- | ---------------------------------------------------------------- |
| `config.example.env`        |                 | The settings, to copy to `~/.config/pml-playbook.env`            |
| `run-on.sh`                 | old machine     | Runs one script on a server with the settings                    |
| `server/bootstrap-root.sh`  | server, root    | Hostname, packages, no automatic reboot, account, lingering, Nix |
| `server/harden-ssh.sh`      | server, root    | Key-only SSH, client keepalive                                   |
| `server/playwright-deps.sh` | server, root    | Ubuntu libraries for Playwright's Chromium                       |
| `user/bootstrap-user.sh`    | server, account | nix-home and its headless Home Manager profile                   |
| `user/clone-pml.sh`         | server, account | PML and docs clones, `.docs` link, direnv, first builds          |
| `user/agents.sh`            | server, account | MCP servers for Claude Code and Codex, Codex's trust             |
| `user/litellm-session.sh`   | server, account | LiteLLM for OMP in the Zellij session `litellm`                  |
| `migrate/lib.sh`            | old machine     | Shared copy and hash-check helpers                               |
| `migrate/branches.sh`       | old machine     | Unpublished branches and worktrees                               |
| `migrate/claude.sh`         | old machine     | Claude Code settings, conversations, memory                      |
| `migrate/codex.sh`          | old machine     | Codex conversations, instructions, preferences                   |
| `migrate/omp.sh`            | old machine     | OMP sessions, settings, memory bank, prompt history              |
| `migrate/omp-bank-name.py`  | either          | OMP's memory bank name for a path                                |
| `migrate/omp-settings.py`   | old machine     | Refuses OMP settings with credentials or a non-default bank      |

`tests/pml-playbook-check.sh` checks every script's syntax and shellcheck, and
runs the migration scripts for real against fake home folders on one machine,
twice: with `DEST_SSH` empty, and through a stand-in `ssh` that, like ssh, reads
its standard input unless given `-n`. It runs `run-on.sh` and `user/agents.sh`
with stand-in `ssh`, `claude`, `codex` and `direnv` commands. The server scripts
themselves only run on a real server.
