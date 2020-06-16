# nix-home

My home environment.

Packages are pinned using [niv](https://github.com/nmattia/niv), which generates/updates the content of the `nix` directory.

### Prereq

- [Nix](https://nixos.org/guides/install-nix.html)
- [Home Manager](https://github.com/rycee/home-manager#installation)

### Install

I'm using my user `pwm` in the 2nd command, replace it with yours for your setup :)

```
$ git clone git@github.com:pwm/nix-home.git ~/nix-home
$ echo "import ~/nix-home/home.nix {user = \"pwm\";}" > ~/.config/nixpkgs/home.nix
$ home-manager switch
```

### Update

```
$ cd ~/nix-home
$ niv update
$ hm switch
```

Note:
`hm` is alias for `run home-manager` where `run` is a small wrapper script to pass
home-manager the updated `NIX_PATH` after a `niv update`.

### iTerm2

Preferences > Profiles > Command: Custom shell:

`/Users/pwm/.nix-profile/bin/fish`

### Missing from nixpkgs:

- assume-role
- saw
