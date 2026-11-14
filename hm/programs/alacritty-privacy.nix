# Reminder for the Dropbox permission of Alacritty on the Mac. macOS keeps the
# Files & Folders permission for one exact Alacritty binary, and each Nix
# rebuild is a new binary to it, so ~/Dropbox gives "Operation not permitted"
# after Alacritty changes. A script cannot give the permission again (tccutil
# can only remove it), so the switch that brings a new Alacritty tells you once,
# in its output and as a banner that opens Files & Folders. The first switch
# only records the current build.
{ pkgs }:
{ config, lib, ... }:
let
  alacritty = config.programs.alacritty.package;
  stamp = "${config.xdg.stateHome}/nix-home/alacritty-build";
  # The banner opens it with `open`: terminal-notifier's -open refuses this
  # URL, as it has no host part.
  settingsUrl = "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders";
in
{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && config.programs.alacritty.enable) {
    home.activation.alacrittyPrivacyReminder = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [[ ! -v DRY_RUN ]]; then
        previous=$(cat ${lib.escapeShellArg stamp} 2>/dev/null || true)
        if [[ -n $previous && $previous != ${alacritty} ]]; then
          warnEcho "Alacritty changed, and macOS sees the new build as a new app."
          warnEcho "If ~/Dropbox gives 'Operation not permitted' after you restart Alacritty,"
          warnEcho "turn on Dropbox for the new alacritty entry in System Settings >"
          warnEcho "Privacy & Security > Files & Folders."
          ${pkgs.terminal-notifier}/bin/terminal-notifier -title "Alacritty changed" \
            -message "After you restart it, turn on Dropbox for its new entry in Files & Folders. Click to open." \
            -execute ${lib.escapeShellArg "/usr/bin/open '${settingsUrl}'"} >/dev/null 2>&1 ||
            warnEcho "Could not show the Alacritty banner"
        fi
        mkdir -p ${lib.escapeShellArg (builtins.dirOf stamp)}
        echo ${alacritty} > ${lib.escapeShellArg stamp}
      fi
    '';
  };
}
