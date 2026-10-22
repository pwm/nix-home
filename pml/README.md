---
title: "PML add-on for the devserver playbook"
date: 2026-10-22
tags: [pml, server, migration]
---

# PML on a new dev server

Follow [the devserver playbook](../devserver/README.md); this add-on adds
what is particular to PML. `pml/project.env` holds PML's settings: the
repositories, the `.docs` link, the hosted service's URL and public OAuth client
ids, and the local application's port.

## Personal settings

In `~/.config/devserver.env`:
- `PROJECTS` includes `work/pml` (and any other checkout you move).
- `DEST_SSH=pml-dev`. Name the SSH aliases `pml-dev` (the account) and
  `pml-dev-root`, as the `pml-dev` helper and PML's runbook (`remote-dev.md` in
  PML) use them.
- `ZAI_KEY_FILE=/home/<you>/work/pml/.envrc.private`, if that file keeps the Z.ai
  key for OMP.

## Steps, in the playbook's order

1. **As root, with the server steps:** the Ubuntu libraries for the browser
   checks. The list is pinned to PML's Playwright; take it again when that pin
   or the Ubuntu release changes.
   ```bash
   devserver/run-on.sh pml-dev-root pml/playwright-deps.sh
   ```
2. **Clone, then build** (some minutes):
   ```bash
   devserver/run-on.sh pml-dev pml/project.env devserver/user/clone-repo.sh
   devserver/run-on.sh pml-dev pml/project.env pml/build.sh
   ```
3. **The private key file.** Create `~/work/pml/.envrc.private` (mode 600) by
   hand, or copy the old one:
   `scp ~/work/pml/.envrc.private pml-dev:work/pml/ && ssh pml-dev chmod 600 work/pml/.envrc.private`.
   It exports `ANTHROPIC_API_KEY` (PML's web chat), `MERMAID_API_KEY` (the
   Mermaid MCP server) and `ZAI_API_KEY` (OMP's GLM model). Never commit it.
   When Claude Code started under `~/work/pml` asks whether to use the
   `ANTHROPIC_API_KEY` it found, answer No, to keep the subscription login.
4. **PML's MCP servers**, after the agents' logins and the playbook's
   `agents.sh`, then the sign-ins the script prints:
   ```bash
   devserver/run-on.sh pml-dev devserver/user/mcp-lib.sh pml/project.env pml/mcp.sh
   ```
   `pml` is the hosted service; `pml-local` reaches `scripts/local.sh` on port
   7334 and connects only while it runs.
5. **Move the work** with the playbook's migration scripts; `work/pml` in
   `PROJECTS` covers PML's branches, worktrees (`.worktrees/`) and agent
   history. Move the docs with Git: commit and push them on the old machine,
   then `git -C ~/work/docs/pml pull --ff-only` on the server.

## PML's checks

- On the server, in a worktree prepared with `scripts/worktree.py`, run PML's
  native gate chains once (`scripts/gates/*.json`, as PML's `AGENTS.md`
  describes). The container chain and the ARM64 release need an ARM64 machine
  and stay on the Mac.
- In each agent, list the PML records through `pml`, and through `pml-local`
  while `scripts/local.sh` runs.

## Files

| File                 | What it does                                                         |
| -------------------- | -------------------------------------------------------------------- |
| `project.env`        | PML's settings: repositories, `.docs`, MCP service and client ids    |
| `playwright-deps.sh` | Ubuntu libraries for the Chromium of PML's pinned Playwright (root)  |
| `build.sh`           | Runtime and Explorer packages, the Explorer page, the engine         |
| `mcp.sh`             | `pml` and `pml-local` for Claude Code and Codex                      |

`tests/pml-addon-check.sh` checks these files and runs `mcp.sh` with stand-in
agent commands.
