{
  enable = true;

  userName = "Zsolt Szende";

  userEmail = "zsolt@artificial.io";

  ignores = [
    ".DS_Store"
    "*.niu"
    ".local"
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

  extraConfig = {
    branch.autosetuprebase = "always";
    push.recurseSubmodules = "no";
    rebase.autosquash = "true";
    submodule.recurse = "true";
    core.pager = "delta";
    interactive.diffFilter = "delta --color-only";
    delta.features = "side-by-side line-numbers";
    delta.whitespace-error-style = "22 reverse";
    rerere.enabled = "true";
  };
}
