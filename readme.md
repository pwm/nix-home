# nix-home

My home environment. Packages are pinned using [niv](https://github.com/nmattia/niv).

## Setup/Install

Install [Alacritty](https://alacritty.org/) on the host, which will then be configured from home-manager.

```
xcode-select --install
curl -L https://nixos.org/nix/install > nix-install
chmod +x nix-install
./nix-install
nix --version
echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf && sudo pkill nix-daemon
git clone git@github.com:pwm/nix-home.git ~/nix-home && cd ~/nix-home
bin/hm-install
bin/hm-run home-manager switch -b backup
```

## Change config

Do whatever change and then run

```
hm switch
```

## Update

```
niv update
hm switch
```

## VSCode extensions

Running the following:

```
vscode-update-extensions
```

will look at the current extensions used (via `code --list-extensions`), download their latest version and write it out to `home/programs/vscode/extensions.json`.

then, as usual, run:

```
hm switch
```
