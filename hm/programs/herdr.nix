# herdr's agent integrations. The Claude Code and Codex hooks report each
# session to herdr, so it can resume the conversations after a server restart;
# the OMP extension also reports OMP's state. The agents own the settings files
# these hooks go into (settings.json, config.toml), so herdr installs them on
# each switch rather than Home Manager linking them; installing again only
# refreshes them. An agent whose directory does not exist on this machine yet
# is skipped. The override variables are cleared so the install always targets
# ~/.claude, ~/.codex and ~/.omp/agent, never the personal ~/.codex-me.
{ pkgs }:
{ lib, ... }:
{
  home.activation.herdrIntegrations = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for target in claude:.claude codex:.codex omp:.omp/agent; do
      if [[ -d $HOME/''${target#*:} ]]; then
        run --quiet env -u CLAUDE_CONFIG_DIR -u CODEX_HOME -u PI_CODING_AGENT_DIR -u PI_CONFIG_DIR \
          ${pkgs.herdr}/bin/herdr integration install "''${target%%:*}" ||
          warnEcho "herdr integration install ''${target%%:*} failed"
      fi
    done
  '';
}
