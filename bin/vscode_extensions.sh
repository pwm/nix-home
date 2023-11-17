#! /usr/bin/env nix-shell
#! nix-shell -i bash -p curl jq unzip
# shellcheck shell=bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

function fail() {
    echo "$1"
    exit 1
}

function clean_up() {
    tmp_dir="${TMPDIR:-/tmp}"
    echo "Script killed, cleaning up tmpdirs: $tmp_dir/vscode_exts_*" >&2
    rm -Rf "$tmp_dir/vscode_exts_*"
}
trap clean_up SIGINT

function get_vsixpkg() {
    publisher="$1"
    name="$2"

    tmp_dir=$(mktemp -d -t vscode_exts_XXXXXXXX)
    url="https://$publisher.gallery.vsassets.io/_apis/public/gallery/publisher/$publisher/extension/$name/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage"
    zip_file="$tmp_dir/$publisher.$name.zip"
    curl --silent --show-error --fail --request GET --output "$zip_file" "$url"
    ver=$(jq -r '.version' <(unzip -qc "$zip_file" "extension/package.json"))
    sha256=$(nix-hash --flat --base32 --type sha256 "$zip_file")
    rm -rf "$tmp_dir"

    cat <<-EOF
  {
    "name": "$name",
    "publisher": "$publisher",
    "version": "$ver",
    "sha256": "$sha256"
  },
EOF
}

echo -n "Ensuring VSCode is present ... "
if ! type -p code &> /dev/null; then 
  fail "VSCode is not found!";
else
  vs_code=$(type -p code)
fi
echo "found at $vs_code"

echo "Downloading and updating extensions:"
json='['
for i in $($vs_code --list-extensions); do
  # ignore updating our own extensions (they are symlinked locally)
  if [[ "$i" == artificialio* ]]; then continue; fi
  echo " - $i ..."
  owner=$(echo "$i" | cut -d. -f1)
  ext=$(echo "$i" | cut -d. -f2)
  json+=$(get_vsixpkg "$owner" "$ext")
done
json+=']'
final_json=$(echo "$json" | tr -d '\n' | sed 's/},]/}]/' | jq -r 'sort_by(.name)')
echo "Latest extension versions downloaded and new extensions.json constructed."

echo -n "Backing old vscode/extensions.json ... "
cp vscode/extensions.json vscode/extensions.json.niu
echo "done, (vscode/extensions.json.niu)."

echo -n "Writing result to vscode/extensions.json ... "
echo "$final_json" > vscode/extensions.json
echo "done."
