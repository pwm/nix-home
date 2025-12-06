{
  enable = true;

  configFile = {
    "fish/functions" = {
      source = ../programs/fish/functions;
      recursive = true;
    };

    # When iterating on the config, it's easier to comment this out and just symlink it:
    # ln -s $HOME/nix-home/hm/programs/nvim/ nvim
    nvim = {
      source = ../programs/nvim;
      recursive = true;
    };

    zellij = {
      source = ../programs/zellij;
      recursive = true;
    };
  };
}
