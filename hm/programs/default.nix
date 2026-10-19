{ pkgs, config }:
{
  delta = import ./delta.nix;

  direnv = import ./direnv.nix;

  fish = import ./fish.nix { inherit pkgs; };

  git = import ./git.nix { gitConfig = config.git; };

  home-manager = import ./home-manager.nix;

  neovim = import ./neovim.nix { inherit pkgs; };

  zellij = import ./zellij.nix { inherit config; };

  man.generateCaches = false;
} // pkgs.lib.optionalAttrs config.desktop {
  alacritty = import ./alacritty.nix { inherit pkgs; inherit (config) homeDirectory; };

  vscode = import ./vscode.nix { inherit pkgs; };

  zed-editor = import ./zed-editor.nix { inherit pkgs; };
}
