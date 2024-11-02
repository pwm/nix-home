{
  # Adds the direnv hook to ~/.config/fish/config.fish
  enable = true;

  nix-direnv.enable = true;

  config = {
    global = {
      hide_env_diff = true;
    };
  };
}
