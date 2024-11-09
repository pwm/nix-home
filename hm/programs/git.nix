{ gitConfig }:
{
  enable = true;

  userName = gitConfig.name;

  userEmail = gitConfig.email;

  ignores = [
    ".DS_Store"
    "*.niu" # "not in use" files
    ".local" # hidden directory
  ];

  aliases = {
    p = "pull -r --autostash";
    co = "checkout";
    c = "commit";
    s = "status";
    b = "branch";
    d = "diff";
    dh = "diff -- '*.hs'";
    da = "diff -- '*.art'";
    dn = "diff -- '*.nix'";
    ds = "diff -- '*.sql'";
    dt = "diff -- '*.tf'";
  };

  delta = {
    enable = true;
    options = {
      features = "side-by-side line-numbers";
      max-line-length = 0;
      whitespace-error-style = "22 reverse";
    };
  };

  # difftastic = {
  #   enable = true;
  #   background = "dark";
  #   display = "side-by-side-show-both";
  # };

  extraConfig = {
    branch.autosetuprebase = "always";
    push.recurseSubmodules = "no";
    rebase.autosquash = "true";
    submodule.recurse = "true";
    rerere.enabled = "true";
  };
}
