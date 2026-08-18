{ pkgs, config }:
{
  stateVersion = "24.05";

  username = "${config.user}";

  homeDirectory = "/Users/${config.user}";

  packages = import ./packages.nix { inherit pkgs; };

  # Deploy global Claude Code instructions to ~/.claude/CLAUDE.md
  file.".claude/CLAUDE.md".source = ../programs/claude/CLAUDE.md;

  # Deploy model providers (local llama-server) to ~/.pi/agent/models.json
  file.".pi/agent/models.json".source = ../programs/pi/models.json;

  # Put the oMLX CLI on PATH (~/.local/bin is in sessionPath). The target is
  # the app's own bootstrap shim (survives app relocation/updates); the app
  # is a manual DMG install, not in nixpkgs.
  file.".local/bin/omlx".source =
    pkgs.runCommand "omlx-cli-link" { } ''
      ln -s /Users/${config.user}/.omlx/bin/omlx $out
    '';

  # home.{sessionPath,sessionVariables} are written to
  # ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  # which in turn is sourced at the top of
  # ~/.config/fish/config.fish
  #
  # Notes:
  #   1. The "at the top" part is important because programs like zellij
  #      rely on the PATH being set when they hook into the shell.
  #      Setting the PATH in programs.fish.interactiveShellInit would place
  #      it _after_ the zellij hook.
  #
  #   2. For now we _also_ have to set PATH in programs.fish.interactiveShellInit
  #      as sessionPath here _appends_ not _prepends_ to the PATH.
  #      This is being discussed and hopefully fixed here:
  #        https://github.com/nix-community/home-manager/issues/3324
  #        https://github.com/nix-community/home-manager/pull/4582/commits/0b25ac41ee
  #      Once fixed we can remove PATH from programs.fish.interactiveShellInit
  sessionPath = [
    "$HOME/nix-home/bin"
    "$HOME/.local/bin"
    "$HOME/.docker/bin"
    "$HOME/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  sessionVariables = {
    NIX_PROFILES = "$HOME/.nix-profile:/nix/var/nix/profiles/default";
    SHELL = "fish";
    TERMINAL = "alacritty";
    EDITOR = "nvim";
    OP_PLUGIN_ALIASES_SOURCED = "1"; # 1password
  };
}
