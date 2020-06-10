set -p fish_function_path /nix/store/xwbr195ym7qas2jgbjqznrl3v4aybh35-fish-foreign-env-git-20200209/share/fish-foreign-env/functions
fenv source $HOME/.nix-profile/etc/profile.d/nix.sh > /dev/null
#fenv source /Users/pwm/.nix-profile/etc/profile.d/hm-session-vars.sh > /dev/null
set -e fish_function_path[1]

set -p NIX_PATH home-manager=/Users/pwm/.nix-defexpr/channels/home-manager nixpkgs=/Users/pwm/.nix-defexpr/channels/nixpkgs
set -p PATH ~/.local/bin

eval (/nix/store/3b2bp4jjl3sr121rgywp74ywkx2bsagg-direnv-2.21.3/bin/direnv hook fish)

alias hm="home-manager"
alias ne="nix-env"
alias cat="bat -p --paging=never"
alias ll="exa -la --git"
alias grep="rg"
alias rgh="rg -g '*.{hs}'"
alias tf="terraform"
alias ar="assume-role"
