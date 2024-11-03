{ pkgs, config }:
{
  alacritty = import ./alacritty.nix { inherit pkgs; inherit (config) user; };

  direnv = import ./direnv.nix;

  fish = import ./fish.nix;

  git = import ./git.nix { gitConfig = config.git; };

  home-manager = import ./home-manager.nix;

  neovim = import ./neovim.nix { inherit pkgs; };

  vscode = import ./vscode.nix { inherit pkgs; };

  zellij = import ./zellij.nix;
}
