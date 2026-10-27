{ pkgs, config }:
{
  stateVersion = "24.05";

  username = "${config.user}";

  homeDirectory = config.homeDirectory;

  packages = import ./packages.nix { inherit pkgs; inherit (config) desktop; };

  # Share personal instructions across agents. Their mutable settings stay
  # outside Home Manager because the applications update them at runtime.
  file = {
    ".claude/CLAUDE.md".source = ../programs/claude/CLAUDE.md;
    ".codex/AGENTS.md".source = ../programs/claude/CLAUDE.md;
    ".codex-me/AGENTS.md".source = ../programs/claude/CLAUDE.md;
    ".omp/agent/AGENTS.md".source = ../programs/claude/CLAUDE.md;

    # Deploy provider registries for Pi and OMP.
    ".pi/agent/models.json".source = ../programs/pi/models.json;
    ".omp/agent/models.yml".source = ../programs/omp/models.yml;
  } // pkgs.lib.optionalAttrs (config.desktop && pkgs.stdenv.hostPlatform.isDarwin) {

    # Put the oMLX CLI on PATH (~/.local/bin is in sessionPath). The target is
    # the app's own bootstrap shim (survives app relocation/updates); the app
    # is a manual DMG install, not in nixpkgs.
    ".local/bin/omlx".source =
      pkgs.runCommand "omlx-cli-link" { } ''
        ln -s ${pkgs.lib.escapeShellArg "${config.homeDirectory}/.omlx/bin/omlx"} $out
      '';
  } // pkgs.lib.optionalAttrs config.desktop {

    # Expose Nixpkgs' zeditor command under Zed's usual CLI name.
    ".local/bin/zed".source = "${pkgs.zed-editor}/bin/zeditor";
  };

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
  #   2. sessionPath is _prepended_ to PATH by hm-session-vars (home-manager
  #      issue 3324 is fixed), but that file is skipped in shells that inherit
  #      __HM_SESS_VARS_SOURCED, while macOS path_helper still moves /usr/bin
  #      to the front in login shells. So programs.fish.interactiveShellInit
  #      re-prepends the same directories with an idempotent fish_add_path.
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
    EDITOR = "nvim";
    OP_PLUGIN_ALIASES_SOURCED = "1"; # 1password
  } // pkgs.lib.optionalAttrs config.desktop {
    TERMINAL = "alacritty";
  } // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    # Prefer Nix's terminfo over Apple's older database. The empty element
    # stands for the compiled-in Nix database.
    TERMINFO_DIRS = "$HOME/.nix-profile/share/terminfo::$TERMINFO_DIRS\${TERMINFO_DIRS:+:}/usr/share/terminfo";
  };
}
