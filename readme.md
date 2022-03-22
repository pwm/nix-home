# nix-home

My home environment. Packages are pinned using [niv](https://github.com/nmattia/niv).

## Nix (assuming M1)

```
/usr/sbin/softwareupdate --install-rosetta --agree-to-license
xcode-select --install
curl -L https://nixos.org/nix/install > nix-install
chmod +x nix-install
arch -x86_64 ./nix-install
nix --version
echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf && sudo pkill nix-daemon
```

## Install

```
git clone git@github.com:pwm/nix-home.git ~/nix-home && cd ~/nix-home
bin/install
```

## Update

```
$ niv update
$ hm switch
```

## Notes to myself

### iTerm2

Preferences > Profiles > Command: Custom shell:

`/Users/pwm/.nix-profile/bin/fish`

### VSCode

Always run it from the cli, ie. `code` and not by clicking the icon in the dock. This way env vars will be present.
