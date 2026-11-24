# herdr-move-workspace up|down: move the active herdr workspace one place up
# or down in the sidebar, bound to Alt+Shift+Up and Alt+Shift+Down in
# hm/programs/herdr/config.toml. Herdr 0.9.5 can move a workspace (its
# workspace.move API method, which the sidebar's mouse drag uses), but has no
# key action or CLI command for it, so this sends the request to herdr's
# socket. A herdr key binding passes the workspace in HERDR_ACTIVE_WORKSPACE_ID,
# the socket in HERDR_SOCKET_PATH and the running herdr binary in
# HERDR_BIN_PATH; a shell in a herdr pane has the last two as well.
{ pkgs }:
pkgs.writeShellApplication {
  name = "herdr-move-workspace";
  runtimeInputs = [ pkgs.herdr pkgs.jq pkgs.socat ];
  text = ''
    usage="usage: herdr-move-workspace up|down [workspace-id]"
    direction=''${1-}
    case $direction in
      up | down) ;;
      *)
        echo "$usage" >&2
        exit 2
        ;;
    esac
    workspace=''${2:-''${HERDR_ACTIVE_WORKSPACE_ID:?$usage}}
    socket=''${HERDR_SOCKET_PATH:?HERDR_SOCKET_PATH is not set, run this from herdr}
    herdr=''${HERDR_BIN_PATH:-herdr}

    # The workspace list is in sidebar order
    ids=$(HERDR_SOCKET_PATH=$socket "$herdr" workspace list | jq -c '[.result.workspaces[].workspace_id]')
    count=$(jq length <<<"$ids")
    index=$(jq --arg id "$workspace" 'index($id) // empty' <<<"$ids")
    if [ -z "$index" ]; then
      echo "herdr-move-workspace: no workspace $workspace" >&2
      exit 1
    fi

    # insert_index counts places before the workspace is taken out, so one
    # place down is index + 2. The first and last workspace stay put.
    if [ "$direction" = up ]; then
      [ "$index" -gt 0 ] || exit 0
      insert=$((index - 1))
    else
      [ "$index" -lt $((count - 1)) ] || exit 0
      insert=$((index + 2))
    fi

    reply=$(jq -cn --arg id "$workspace" --argjson insert "$insert" \
      '{id: "herdr-move-workspace", method: "workspace.move", params: {workspace_id: $id, insert_index: $insert}}' |
      socat - "UNIX-CONNECT:$socket")
    if ! jq -e '.result' <<<"$reply" >/dev/null; then
      echo "herdr-move-workspace: $reply" >&2
      exit 1
    fi
  '';
}
