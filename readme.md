# nix-home

My home environment that can be set up using home-manager.

### Install

```
$ git clone git@github.com:pwm/nix-home.git ~/nix-home
$ echo "import ~/nix-home/home.nix" > ~/.config/nixpkgs/home.nix
$ home-manager switch
```

### Missing from nixpkgs:
- assume-role
- hub
- saw
