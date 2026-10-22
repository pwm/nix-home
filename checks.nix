# Evaluate both supported profiles without building or activating either one:
# NIXPKGS_ALLOW_UNFREE=1 nix-instantiate --eval --strict --json checks.nix
let
  sources = import ./nix/sources.nix;
  check = system: overrides:
    let
      pkgs = import sources.nixpkgs { inherit system; };
      ext_config = {
        user = "profile-check";
        git = { name = "Profile check"; email = "check@example.invalid"; };
      } // overrides;
      module = import ./default.nix { inherit system ext_config; };
      evaluated = import (sources.home-manager + "/modules") {
        inherit pkgs;
        configuration = module;
      };
      cfg = evaluated.config;
      desktop = overrides.desktop or pkgs.stdenv.hostPlatform.isDarwin;
      expectedHome = overrides.homeDirectory or
        (if pkgs.stdenv.hostPlatform.isDarwin then "/Users/profile-check" else "/home/profile-check");
      names = map pkgs.lib.getName module.home.packages;
      has = name: builtins.elem name names;
      guiPackages = [ "vscode" "inkscape" "sqlitebrowser" "fira-code" "fira-code-symbols" ];
      agentFiles = [ ".claude/CLAUDE.md" ".codex/AGENTS.md" ".omp/agent/AGENTS.md" ];
    in
    assert cfg.home.homeDirectory == expectedHome;
    assert builtins.all has [ "claude-code" "codex" "omp" "fff-mcp" "fish" "zellij" ];
    assert builtins.all (name: has name == desktop) guiPackages;
    assert cfg.programs.alacritty.enable == desktop;
    assert cfg.programs.vscode.enable == desktop;
    assert cfg.programs.zed-editor.enable == desktop;
    assert cfg.fonts.fontconfig.enable == desktop;
    assert cfg.programs.fish.enable && cfg.programs.zellij.enable && cfg.programs.neovim.enable;
    assert cfg.programs.zellij.enableFishIntegration == desktop;
    assert (pkgs.lib.hasInfix "setup --generate-auto-start fish" cfg.programs.fish.interactiveShellInit) == desktop;
    assert builtins.all (name: builtins.hasAttr name cfg.home.file) agentFiles;
    assert (builtins.hasAttr ".local/bin/omlx" cfg.home.file) == (desktop && pkgs.stdenv.hostPlatform.isDarwin);
    assert (builtins.hasAttr ".local/bin/zed" cfg.home.file) == desktop;
    assert (builtins.hasAttr "TERMINAL" cfg.home.sessionVariables) == desktop;
    assert (builtins.hasAttr "s" cfg.programs.fish.shellAliases) == pkgs.stdenv.hostPlatform.isDarwin;
    assert has "openssh" == pkgs.stdenv.hostPlatform.isDarwin;
    assert !desktop || cfg.programs.alacritty.settings.terminal.shell.program == "${expectedHome}/.nix-profile/bin/fish";
    {
      homeDirectory = cfg.home.homeDirectory;
      inherit desktop;
      zellijAutoStart = cfg.programs.zellij.enableFishIntegration;
      # Force the complete Home Manager option/derivation checks, not just
      # the subset of fields asserted above. This still builds nothing.
      activation = evaluated.activationPackage.drvPath;
      agents = map (p: { inherit (p) name; derivation = p.drvPath; })
        (builtins.filter (p: builtins.elem (pkgs.lib.getName p) [ "claude-code" "codex" "omp" ]) module.home.packages);
    };
in
{
  mac = check "aarch64-darwin" { };
  linux = check "x86_64-linux" { };
  customHome = check "x86_64-linux" { homeDirectory = "/srv/profile-check"; desktop = false; };
  headlessMac = check "aarch64-darwin" { desktop = false; };
}
