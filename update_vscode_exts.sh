#! /usr/bin/env nix-shell
#! nix-shell -i bash -p curl jq unzip
# shellcheck shell=bash
set -eu -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/"

function fail() {
    echo "$1" >&2
    exit 1
}

function clean_up() {
    TDIR="${TMPDIR:-/tmp}"
    echo "Script killed, cleaning up tmpdirs: $TDIR/vscode_exts_*" >&2
    rm -Rf "$TDIR/vscode_exts_*"
}
trap clean_up SIGINT

function get_vsixpkg() {
    N="$1.$2"

    # Create a tempdir for the extension download
    EXTTMP=$(mktemp -d -t vscode_exts_XXXXXXXX)

    URL="https://$1.gallery.vsassets.io/_apis/public/gallery/publisher/$1/extension/$2/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage"

    # Quietly but delicately curl down the file, blowing up at the first sign of trouble.
    curl --silent --show-error --fail -X GET -o "$EXTTMP/$N.zip" "$URL"
    # Unpack the file we need to stdout then pull out the version
    VER=$(jq -r '.version' <(unzip -qc "$EXTTMP/$N.zip" "extension/package.json"))
    # Calculate the SHA
    SHA=$(nix-hash --flat --base32 --type sha256 "$EXTTMP/$N.zip")

    # Clean up.
    rm -Rf "$EXTTMP"
    # I don't like 'rm -Rf' lurking in my scripts but this seems appropriate

    cat <<-EOF
  {
    "name": "$2",
    "publisher": "$1",
    "version": "$VER",
    "sha256": "$SHA"
  },
EOF
}

vs_code=$(command -v code)
if [ -z "$vs_code" ]; then
    fail "VSCode executable not found"
fi
echo "Found $vs_code"

echo "About to update extensions ..."
json='['
for i in $($vs_code --list-extensions)
do
    OWNER=$(echo "$i" | cut -d. -f1)
    EXT=$(echo "$i" | cut -d. -f2)
    json+=$(get_vsixpkg "$OWNER" "$EXT")
done
json+=']'

echo "Writing result to vscode/extensions.json ..."
echo "$json" | tr -d '\n' | sed 's/},]/}]/' | jq -r 'sort_by(.name)' > vscode/extensions.json
echo "Output written to vscode/extensions.json"
