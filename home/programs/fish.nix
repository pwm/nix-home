{
  user,
  pkgs,
  hm,
}: {
  enable = true;

  # Appended to ~/.config/fish/config.fish
  # See note on home.sessionPath
  interactiveShellInit = ''
    set -p PATH $HOME/nix-home/bin $HOME/.local/bin $HOME/.docker/bin $HOME/.nix-profile/bin /nix/var/nix/profiles/default/bin

    zellij_tab_names
  '';

  shellAliases = {
    hm = "run home-manager";
    h = "history | fzy";
    f = "fd | fzy";
    ll = "exa -la --git";
    cat = "bat -pp";
    rga = "rg -g '*.{art}'";
    rgb = "rg -g '*.{sh}'";
    rgh = "rg -g '*.{hs}'";
    rgj = "rg -g '*.{js,ts,tsx}'";
    rgjs = "rg -g '*.{json}'";
    rgn = "rg -g '*.{nix}'";
    rgs = "rg -g '*.{sql}'";
    rgt = "rg -g '*.{tf}'";
    gt = "git ls-tree -r --name-only HEAD 2>/dev/null | tree -C --fromfile";
    gf = "git commit -a --fixup=(git rev-parse HEAD | cut -c 1-8)";
    b = "git for-each-ref refs/heads --format='%(refname:short)' --sort='refname' | fzy --query \"$argv\" | xargs git checkout";
    bm = "git checkout master";
    bd = "git for-each-ref refs/heads --format='%(refname:short)' --sort='refname' | rg -v master | fzy --query \"$argv\" | xargs git branch -D";
    p = "git push origin (git branch --show-current)";
    pr = "gh pr create --fill";
    ppr = "p && pr";
    gfp = "gf && p";
    s = "pbpaste | nc termbin.com 9999";
  };
}
