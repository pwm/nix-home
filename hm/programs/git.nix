{ gitConfig }:
{
  enable = true;

  ignores = [
    ".DS_Store"
    "*.niu" # "not in use" files
    ".local" # hidden directory
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
