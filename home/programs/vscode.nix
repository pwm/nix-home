{ pkgs }:
let
  importJSON = path: (builtins.fromJSON (builtins.readFile path));
in
{
  enable = true;

  # Some defaults just for notes
  # enableUpdateCheck = true;
  # enableExtensionUpdateCheck = true;
  # mutableExtensionsDir = true;

  package = pkgs.vscode; # Use our version

  # To update extensions.json run: vscode-update-extensions
  extensions =
    pkgs.vscode-utils.extensionsFromVscodeMarketplace
      (importJSON ./vscode/extensions.json);

  keybindings = importJSON ./vscode/keybindings.json;

  userSettings = importJSON ./vscode/settings.json;

  userTasks = { };
}
