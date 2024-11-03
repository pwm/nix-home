{
  enable = true;

  configFile = {
    "fish/fish_variables".source = ../programs/fish/fish_variables;
    "fish/functions/fish_prompt.fish".source = ../programs/fish/functions/fish_prompt.fish;
    "fish/functions/zellij_tab_names.fish".source = ../programs/fish/functions/zellij_tab_names.fish;
    "zellij/config.kdl".source = ../programs/zellij/config.kdl;

    # nvim.source = ../programs/nvim/init.lua;

    # nvim = {
    #   source = ../programs/nvim;
    #   recursive = true;
    # };
  };
}
