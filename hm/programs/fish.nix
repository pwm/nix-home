{
  enable = true;

  # Appended to ~/.config/fish/config.fish
  interactiveShellInit = ''
    # Don't delete PATH from here !!! See notes in home.sessionPath
    set -p PATH $HOME/nix-home/bin $HOME/.local/bin $HOME/.docker/bin $HOME/.nix-profile/bin /nix/var/nix/profiles/default/bin

    # files with multiple functions need manual sourcing (fish by default likes 1 function per file)
    source $HOME/.config/fish/functions/zellij.fish

    # So that it fires upon opening a new tab
    zellij_tab_names
  '';

  shellAliases = {
    hm = "hm-run home-manager";
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
    bm = "git checkout master 2>/dev/null || git checkout main";
    bd = "git for-each-ref refs/heads --format='%(refname:short)' --sort='refname' | rg -v \"master|main\" | fzy --query \"$argv\" | xargs git branch -D";
    p = "git push origin (git branch --show-current)";
    pr = "gh pr create --fill";
    ppr = "p && pr";
    gfp = "gf && p";
    s = "pbpaste | nc termbin.com 9999";
    cdr = "set -q PRJ_ROOT; and cd $PRJ_ROOT; or cd .";
    ngrok = "op plugin run -- ngrok";
  };
}
