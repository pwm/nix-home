{ pkgs }:
{ config, lib, ... }:
let
  extensions = import ./vscode/extensions.nix { inherit pkgs; };
  extensionRoot = ".vscode-server/extensions";
  desired = pkgs.writeText "vscode-remote-extensions.json"
    (pkgs.vscode-utils.toExtensionJson extensions);
in
{
  # Keep the server's directory and registry writable. Only these links belong
  # to Home Manager; extensions installed through the editor remain alongside.
  home.file = builtins.listToAttrs (map
    (extension: {
      name = "${extensionRoot}/.nix-home/${extension.vscodeExtUniqueId}";
      value.source = "${extension}/share/vscode/extensions/${extension.vscodeExtUniqueId}";
    })
    extensions);

  home.activation.vscodeRemoteExtensions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${pkgs.python3}/bin/python3 ${./vscode/remote-extensions.py} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/${extensionRoot}"} ${desired}
  '';
}
