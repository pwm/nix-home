{ gitConfig }:
{
  enable = true;

  ignores = [
    ".DS_Store"
    "*.niu" # "not in use" files
    ".local" # hidden directory
    ".docs" # hidden directory
  ];

  settings = {
    user = {
      name = gitConfig.name;
      email = gitConfig.email;
    };

    branch.autosetuprebase = "always";
    push.recurseSubmodules = "no";
    rebase.autosquash = "true";
    submodule.recurse = "true";
    rerere.enabled = "true";
    # home-manager's delta module now only sets pager.{blame,diff,log,show}.
    # Keep delta for everything else that is paged too (git grep, stash show, ...).
    core.pager = "delta";

    alias = {
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
  };
}
