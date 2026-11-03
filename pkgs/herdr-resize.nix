# herdr-resize grow|shrink: Zellij's Alt+= and Alt+- for herdr, bound in
# hm/programs/herdr/config.toml. Herdr's own resize moves one border in one
# direction and ignores the sign of --amount, so this goes over each side of
# the focused pane that has a neighbour. To grow, it moves that border away
# from the pane; to shrink, it resizes the neighbour towards the pane.
# A herdr key binding passes the pane in HERDR_ACTIVE_PANE_ID and the running
# herdr binary in HERDR_BIN_PATH.
{ pkgs }:
pkgs.writeShellApplication {
  name = "herdr-resize";
  runtimeInputs = [ pkgs.herdr pkgs.jq ];
  text = ''
    usage="usage: herdr-resize grow|shrink [pane-id]"
    mode=''${1-}
    case $mode in
      grow | shrink) ;;
      *)
        echo "$usage" >&2
        exit 2
        ;;
    esac
    pane=''${2:-''${HERDR_ACTIVE_PANE_ID:?$usage}}
    herdr=''${HERDR_BIN_PATH:-herdr}
    step=0.05 # the step of herdr's resize mode

    opposite() {
      case $1 in
        left) echo right ;;
        right) echo left ;;
        up) echo down ;;
        down) echo up ;;
      esac
    }

    # pane edges is true on the sides that touch the outer edge, and false
    # where the pane has a neighbour
    "$herdr" pane edges --pane "$pane" |
      jq -r '.result.edges | to_entries[] | select(.value == false) | .key' |
      while read -r side; do
        if [ "$mode" = grow ]; then
          "$herdr" pane resize --pane "$pane" --direction "$side" --amount "$step" >/dev/null
        else
          neighbour=$("$herdr" pane neighbor --pane "$pane" --direction "$side" |
            jq -r '.result.neighbor.neighbor_pane_id // empty')
          if [ -n "$neighbour" ]; then
            "$herdr" pane resize --pane "$neighbour" --direction "$(opposite "$side")" --amount "$step" >/dev/null
          fi
        fi
      done
  '';
}
