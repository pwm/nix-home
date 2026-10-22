#!/usr/bin/env bash
# Offline checks of the real updater. The editor, Marketplace and hash tool
# are stubs; the fixture lives outside the checkout and never installs anything.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/repo/bin" "$scratch/repo/hm/programs/vscode" "$scratch/stubs"
cp "$root/bin/vscode-update-extensions" "$scratch/repo/bin/"
catalogue=$scratch/repo/hm/programs/vscode/extensions.json
cat >"$scratch/original.json" <<'JSON'
[
  {"publisher":"desktop","name":"theme","version":"1","sha256":"old-theme"},
  {"publisher":"haskell","name":"haskell","version":"1","sha256":"old-haskell"},
  {"publisher":"ms-python","name":"python","version":"1","platforms":{"darwin-arm64":"old-mac","linux-x64":"old-linux"}}
]
JSON

cat >"$scratch/stubs/code" <<'SH'
#!/usr/bin/env bash
case "$1" in
--version) echo '1.110.0' ;;
--list-extensions)
  printf '%s\n' haskell.haskell fresh.extension
  if [[ ${FAIL_LIST:-0} == 1 ]]; then exit 7; fi
  ;;
*) exit 2 ;;
esac
SH
cat >"$scratch/stubs/curl" <<'PY'
#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
url = args[-1]
if '--data' in args:
    name = json.loads(args[args.index('--data') + 1])['filters'][0]['criteria'][0]['value']
    base = {'version': '2', 'properties': [{'key': 'Microsoft.VisualStudio.Code.Engine', 'value': '^1.100.0'}]}
    if name == 'ms-python.python':
        # The latest version is only available on the Mac. Both machines
        # must move together to the next version that supports both.
        versions = [dict(base, version='3', targetPlatform='darwin-arm64')]
        versions += [dict(base, targetPlatform=p) for p in ['darwin-arm64', 'linux-x64']]
        if os.environ.get('MISSING_PLATFORM') == '1':
            versions = versions[:1]
    else:
        versions = [base]
    print(json.dumps({'results': [{'extensions': [{'versions': versions}]}]}))
else:
    with open(os.environ['TEST_URLS'], 'a') as f:
        f.write(url + '\n')
    pathlib.Path(args[args.index('--output') + 1]).write_text(url)
    if os.environ.get('FAIL_DOWNLOAD') == '1' and url.endswith('targetPlatform=linux-x64'):
        sys.exit(22)
PY
cat >"$scratch/stubs/nix-hash" <<'PY'
#!/usr/bin/env python3
import pathlib, sys
url = pathlib.Path(sys.argv[-1]).read_text()
print('hash-' + url.split('targetPlatform=')[1] if 'targetPlatform=' in url else 'hash-universal')
PY
chmod +x "$scratch/stubs/"*
export PATH="$scratch/stubs:$PATH"
export TEST_URLS="$scratch/urls"
helper=$scratch/repo/bin/vscode-update-extensions

reset_fixture() {
  cp "$scratch/original.json" "$catalogue"
  : >"$TEST_URLS"
}
run() {
  bash "$helper" --code "$scratch/stubs/code" >"$scratch/output" 2>&1
}
assert_no_scratch() {
  [[ -z $(find "$scratch/repo/hm/programs/vscode" -name '.update-extensions.*' -print) ]]
}

reset_fixture
run
jq -e 'length == 4 and any(.[]; .publisher == "desktop" and .name == "theme") and any(.[]; .publisher == "fresh" and .name == "extension")' "$catalogue" >/dev/null
echo 'PASS: sparse remote list retains desktop pins and adds newly installed extensions'
jq -e '.[] | select(.publisher == "ms-python") | .version == "2" and .platforms == {"darwin-arm64":"hash-darwin-arm64","linux-x64":"hash-linux-x64"} and (has("sha256") | not) and (has("arch") | not)' "$catalogue" >/dev/null
[[ $(rg -c 'targetPlatform=' "$TEST_URLS") == 2 ]]
echo 'PASS: one shared version fetches both platform hashes, skipping a one-platform update'
jq -e '.[] | select(.publisher == "haskell") | .sha256 == "hash-universal" and (has("platforms") | not)' "$catalogue" >/dev/null
assert_no_scratch
echo 'PASS: universal extensions stay universal and temporary files are removed'

reset_fixture
MISSING_PLATFORM=1 run
jq -e '.[] | select(.publisher == "ms-python") | .version == "1" and .platforms == {"darwin-arm64":"old-mac","linux-x64":"old-linux"}' "$catalogue" >/dev/null
echo 'PASS: missing platform retains the complete old pin'

reset_fixture
if FAIL_DOWNLOAD=1 run; then
  echo 'FAIL: failed second-platform download succeeded' >&2
  exit 1
fi
cmp "$scratch/original.json" "$catalogue"
assert_no_scratch
echo 'PASS: failed download preserves the original catalogue, removing temporary files'

reset_fixture
if FAIL_LIST=1 run; then
  echo 'FAIL: failed editor listing succeeded' >&2
  exit 1
fi
cmp "$scratch/original.json" "$catalogue"
[[ ! -s $TEST_URLS ]]
assert_no_scratch
echo 'PASS: failed editor listing refuses before downloads or catalogue changes'
