{ pkgs }:
let
  importJSON = path: (builtins.fromJSON (builtins.readFile path));
in
{
  enable = true;

  package = pkgs.vscode; # Use our version

  # To update extensions.json run: bin/vscode_extensions.sh
  extensions =
    pkgs.vscode-utils.extensionsFromVscodeMarketplace
      (importJSON ./vscode/extensions.json);

  keybindings = importJSON ./vscode/keybindings.json;

  userSettings = importJSON ./vscode/settings.json;

  userTasks = { };
}
