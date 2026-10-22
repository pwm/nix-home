{ pkgs }:
let
  lib = pkgs.lib;
  entries = builtins.fromJSON (builtins.readFile ./extensions.json);
  platforms = {
    aarch64-darwin = "darwin-arm64";
    x86_64-linux = "linux-x64";
  };
  platform = platforms.${pkgs.stdenv.hostPlatform.system} or
    (throw "VS Code extensions: unsupported system ${pkgs.stdenv.hostPlatform.system}");
  ids = map (entry: "${entry.publisher}.${entry.name}") entries;
  select = entry:
    if entry ? platforms then
      assert !(entry ? arch || entry ? sha256);
      (builtins.removeAttrs entry [ "platforms" ]) // {
        arch = platform;
        sha256 = entry.platforms.${platform} or
          (throw "VS Code extension ${entry.publisher}.${entry.name} has no ${platform} pin");
      }
    else
      assert !(entry ? arch);
      entry;
in
assert builtins.length ids == builtins.length (lib.unique ids);
pkgs.vscode-utils.extensionsFromVscodeMarketplace (map select entries)
