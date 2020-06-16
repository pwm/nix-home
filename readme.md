# nix-home

My home environment that can be set up using home-manager.

Packages are pinned using [niv](https://github.com/nmattia/niv) (which generates the content of the `nix` directory).

### Prereq

- [Nix](https://nixos.org/guides/install-nix.html)
- [Home Manager](https://github.com/rycee/home-manager#installation)

### Install

I'm using `pwm`, my user, but do replace it with yours for your setup :)

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

### iTerm2

Preferences > Profiles > Command: Custom shell:

`/Users/pwm/.nix-profile/bin/fish`

### Missing from nixpkgs:

- assume-role
- saw
