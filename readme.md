# nix-home

My home environment. Packages are pinned using [niv](https://github.com/nmattia/niv).

## Setup/Install

Install Alacritty on the host. It'll then be configured from home-manager.

```
xcode-select --install
curl -L https://nixos.org/nix/install > nix-install
chmod +x nix-install
./nix-install
nix --version
echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf && sudo pkill nix-daemon
git clone git@github.com:pwm/nix-home.git ~/nix-home && cd ~/nix-home
bin/install
```

## Update

```
$ niv update
$ hm switch
```
