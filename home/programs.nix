{ user, pkgs }:
{
  alacritty = import ./programs/alacritty.nix { inherit user pkgs; };

  direnv = import ./programs/direnv.nix;

  fish = import ./programs/fish.nix;

  git = import ./programs/git.nix;

  home-manager = import ./programs/home-manager.nix;

  neovim = import ./programs/neovim.nix { inherit pkgs; };

  vscode = import ./programs/vscode.nix { inherit pkgs; };

  zellij = import ./programs/zellij.nix;
}
