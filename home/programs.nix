{
  user,
  pkgs,
  hm,
}: {
  home-manager.enable = true;

  # Add the direnv hook to ~/.config/fish/config.fish
  direnv.enable = true;

  alacritty = import ./programs/alacritty.nix {inherit pkgs;};

  fish = import ./programs/fish.nix {inherit user pkgs hm;};

  git = import ./programs/git.nix;

  neovim = import ./programs/neovim.nix {inherit pkgs;};

  vscode = import ./programs/vscode.nix {inherit pkgs;};

  zellij = import ./programs/zellij.nix;
}
