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

  profiles.default = {
    # To update extensions.json run: vscode-update-extensions
    extensions = import ./vscode/extensions.nix { inherit pkgs; };

    keybindings = importJSON ./vscode/keybindings.json;

    userSettings = importJSON ./vscode/settings.json;

    userTasks = { };
  };
}
