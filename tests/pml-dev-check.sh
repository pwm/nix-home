#!/usr/bin/env bash
# Offline controls for bin/pml-dev: ssh, scp and herdr are stubs that record
# their arguments and input, so nothing connects; pbcopy is a stub, so the
# clipboard stays untouched. Run: tests/pml-dev-check.sh
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
helper=$root/bin/pml-dev
stubs=$(mktemp -d)
trap 'rm -rf "$stubs"' EXIT
# A connection prints the contents of $stubs/reply, when the test wrote one,
# and fails when $stubs/fail exists. Every call is also added to $stubs/calls.
for tool in ssh scp; do
  cat >"$stubs/$tool" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$tool" "\$@" >"$stubs/argv"
printf '%s\n' "$tool" "\$@" >>"$stubs/calls"
cat >"$stubs/stdin"
[[ ! -f $stubs/fail ]] || exit 255
[[ ! -f $stubs/reply ]] || cat "$stubs/reply"
EOF
  chmod +x "$stubs/$tool"
done
# The Mac's herdr client, which `herdr` runs last; it keeps $stubs/stdin.
cat >"$stubs/herdr" <<EOF
#!/usr/bin/env bash
printf '%s\n' herdr "\$@" >"$stubs/argv"
printf '%s\n' herdr "\$@" >>"$stubs/calls"
EOF
chmod +x "$stubs/herdr"
cat >"$stubs/pbcopy" <<EOF
#!/usr/bin/env bash
cat >"$stubs/clipboard"
EOF
chmod +x "$stubs/pbcopy"

passed=0
failed=0
ok() {
  if [[ $2 == true ]]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL: $1" >&2
  fi
}

# Runs the helper; sets $status, $argv (the last stub's recorded arguments, or
# empty), $calls (every stub call in order), $stdin (the connection's input)
# and $clipboard (what pbcopy received).
run() {
  rm -f "$stubs/argv" "$stubs/calls" "$stubs/stdin" "$stubs/clipboard"
  set +e
  PATH="$stubs:$PATH" "$helper" "$@" </dev/null >/dev/null 2>&1
  status=$?
  set -e
  argv=$([[ -f $stubs/argv ]] && cat "$stubs/argv" || true)
  calls=$([[ -f $stubs/calls ]] && cat "$stubs/calls" || true)
  stdin=$([[ -f $stubs/stdin ]] && cat "$stubs/stdin" || true)
  clipboard=$([[ -f $stubs/clipboard ]] && cat "$stubs/clipboard" || true)
}

attach_argv() {
  printf '%s\n' ssh -t pml-dev "exec ~/.nix-profile/bin/fish -l -c 'exec zellij attach -c $1'"
}

run
ok "no command prints the usage and connects to nothing" \
  "$([[ $status == 1 && -z $calls ]] && echo true)"
run attach
ok "the old attach command is gone and connects to nothing" \
  "$([[ $status == 1 && -z $calls ]] && echo true)"
run zellij
ok "zellij without a name attaches to the default session pml" \
  "$([[ $status == 0 && $argv == "$(attach_argv pml)" ]] && echo true)"
run zellij work-2_b
ok "zellij with a normal name passes it as the session" \
  "$([[ $status == 0 && $argv == "$(attach_argv work-2_b)" ]] && echo true)"

# shellcheck disable=SC2016 # the '$' is a literal character under test
for name in -f --help -c help options "a;b" 'a b' 'a$b' "a'b" _x; do
  run zellij "$name"
  ok "zellij refuses the session name '$name' without connecting" \
    "$([[ $status == 1 && -z $argv ]] && echo true)"
done
run zellij a b
ok "zellij refuses a second argument without connecting" \
  "$([[ $status == 1 && -z $argv ]] && echo true)"

run forward 7444
ok "forward passes the same loopback port on both ends" \
  "$([[ $status == 0 && $argv == "$(printf '%s\n' ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:7444:127.0.0.1:7444 pml-dev)" ]] && echo true)"
for port in 80 1023 65536 07444 0x1f 99999999999999999999 abc ""; do
  run forward "$port"
  ok "forward refuses the port '$port' without connecting" \
    "$([[ $status == 1 && -z $argv ]] && echo true)"
done
run forward 7444 7445
ok "forward refuses a second argument without connecting" \
  "$([[ $status == 1 && -z $argv ]] && echo true)"

run put "a file" "dir/b c"
ok "put keeps a name with spaces as one argument" \
  "$([[ $status == 0 && $argv == "$(printf '%s\n' scp -r -- "a file" "pml-dev:dir/b c")" ]] && echo true)"
run get "x y"
ok "get copies to the current directory by default" \
  "$([[ $status == 0 && $argv == "$(printf '%s\n' scp -r -- "pml-dev:x y" .)" ]] && echo true)"
run put
ok "put without a source refuses without connecting" \
  "$([[ $status == 1 && -z $argv ]] && echo true)"

shot_argv() {
  printf '%s\n' ssh "${2:-pml-dev}" "mkdir -p shots && cat > shots/$1 && echo \"\$HOME/shots/$1\""
}

# A Mac home whose Desktop holds two screenshots and a newer file of another kind.
mac=$stubs/mac
mkdir -p "$mac/Desktop"
printf old >"$mac/Desktop/Screenshot 2026-10-25 at 10.19.36.png"
printf new >"$mac/Desktop/Screenshot 2026-10-25 at 10.20.28.png"
printf notes >"$mac/Desktop/notes.txt"
touch -t 202610251019 "$mac/Desktop/Screenshot 2026-10-25 at 10.19.36.png"
touch -t 202610251020 "$mac/Desktop/Screenshot 2026-10-25 at 10.20.28.png"
touch -t 202610251030 "$mac/Desktop/notes.txt"

newest=Screenshot-2026-10-25-at-10.20.28.png
echo "/home/pwm/shots/$newest" >"$stubs/reply"
HOME=$mac run shot
ok "shot without a file uploads the newest Desktop screenshot under a name without spaces" \
  "$([[ $status == 0 && $argv == "$(shot_argv $newest)" && $stdin == new ]] && echo true)"
ok "shot puts the server path on the clipboard" \
  "$([[ $clipboard == "/home/pwm/shots/$newest" ]] && echo true)"

# shellcheck disable=SC2016 # the '$' is a literal character under test
odd="$stubs/a b\$(x);'c.png"
printf odd >"$odd"
echo "/home/pwm/shots/a-b-x-c.png" >"$stubs/reply"
run shot "$odd"
ok "shot with a file uploads that file, with only safe characters in the remote name" \
  "$([[ $status == 0 && $argv == "$(shot_argv a-b-x-c.png)" && $stdin == odd ]] && echo true)"

nnbsp=$' '
printf pm >"$stubs/Screenshot at 1.02.03${nnbsp}PM.png"
echo "/home/pwm/shots/Screenshot-at-1.02.03-PM.png" >"$stubs/reply"
run shot "$stubs/Screenshot at 1.02.03${nnbsp}PM.png"
ok "shot replaces the narrow space before AM/PM with one '-'" \
  "$([[ $status == 0 && $argv == "$(shot_argv Screenshot-at-1.02.03-PM.png)" ]] && echo true)"

echo "Welcome!" >"$stubs/reply"
run shot "$odd"
ok "shot refuses an unexpected reply and leaves the clipboard alone" \
  "$([[ $status == 1 && -z $clipboard ]] && echo true)"
rm "$stubs/reply"

mkdir -p "$stubs/empty/Desktop"
HOME=$stubs/empty run shot
ok "shot without a file refuses an empty Desktop without connecting" \
  "$([[ $status == 1 && -z $argv && -z $clipboard ]] && echo true)"
for file in "$stubs/missing.png" "$stubs" ""; do
  run shot "$file"
  ok "shot refuses '$file', which is no file, without connecting" \
    "$([[ $status == 1 && -z $argv ]] && echo true)"
done
run shot "$odd" "$odd"
ok "shot refuses a second argument without connecting" \
  "$([[ $status == 1 && -z $argv ]] && echo true)"

run --help
ok "--help prints the usage and connects to nothing" \
  "$([[ $status == 0 && -z $argv ]] && echo true)"
run nonsense
ok "an unknown command refuses without connecting" \
  "$([[ $status == 1 && -z $argv ]] && echo true)"

DEVSERVER_HOST=devbox DEVSERVER_SESSION=main run zellij
ok "DEVSERVER_HOST and DEVSERVER_SESSION choose another server and default session" \
  "$([[ $status == 0 && $argv == "$(printf '%s\n' ssh -t devbox "exec ~/.nix-profile/bin/fish -l -c 'exec zellij attach -c main'")" ]] && echo true)"
DEVSERVER_HOST=devbox run get x
ok "DEVSERVER_HOST also names the server for copies" \
  "$([[ $status == 0 && $argv == "$(printf '%s\n' scp -r -- devbox:x .)" ]] && echo true)"
echo "/home/pwm/shots/a-b-x-c.png" >"$stubs/reply"
DEVSERVER_HOST=devbox run shot "$odd"
ok "DEVSERVER_HOST also names the server for shot" \
  "$([[ $status == 0 && $argv == "$(shot_argv a-b-x-c.png devbox)" ]] && echo true)"
rm "$stubs/reply"
DEVSERVER_HOST='' run zellij
ok "an empty DEVSERVER_HOST keeps pml-dev" \
  "$([[ $status == 0 && $argv == "$(attach_argv pml)" ]] && echo true)"
DEVSERVER_HOST=-oProxyCommand=x run forward 7444
ok "a DEVSERVER_HOST that ssh would read as an option refuses without connecting" \
  "$([[ $status == 1 && -z $argv ]] && echo true)"
DEVSERVER_SESSION=-f run zellij
ok "a DEVSERVER_SESSION that is no session name refuses without connecting" \
  "$([[ $status == 1 && -z $argv ]] && echo true)"

herdr_attach_calls() {
  printf '%s\n' ssh "${1:-pml-dev}" 'exec ~/.nix-profile/bin/fish -l' \
    herdr --remote "${1:-pml-dev}" --remote-keybindings server
}

run herdr
ok "herdr starts a missing server from a login Fish, then attaches with the server's keys" \
  "$([[ $status == 0 && $calls == "$(herdr_attach_calls)" ]] && echo true)"
ok "the login Fish starts the server only when none runs, detached, and waits for it" \
  "$([[ $stdin == *"if not herdr status | string match -q '*status: running*'"* && $stdin == *'setsid -f herdr server </dev/null >/dev/null 2>&1'* && $stdin == *'sleep 0.1'* ]] && echo true)"
run herdr pml
ok "herdr refuses a session name without connecting" \
  "$([[ $status == 1 && -z $calls ]] && echo true)"
touch "$stubs/fail"
run herdr
ok "herdr stops when the server cannot be reached, before attaching" \
  "$([[ $status != 0 && $calls == "$(printf '%s\n' ssh pml-dev 'exec ~/.nix-profile/bin/fish -l')" ]] && echo true)"
rm "$stubs/fail"
DEVSERVER_HOST=devbox run herdr
ok "DEVSERVER_HOST also names the server for herdr" \
  "$([[ $status == 0 && $calls == "$(herdr_attach_calls devbox)" ]] && echo true)"

echo "$passed passed, $failed failed"
((failed == 0))
