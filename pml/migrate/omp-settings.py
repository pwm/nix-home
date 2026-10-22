"""Check OMP's config.yml before a migration copies it.

Prints one line per reason the file may not be copied as it is, each tagged:
- `credential:` a setting OMP 18.5.1 marks as a credential (the playbook leaves
  credentials for manual setup on the new machine), or syntax this check cannot
  read near one;
- `bank:` a non-default memory bank (`mnemopi.bank`, `mnemopi.dbPath`, or a
  scoping other than per-project), or syntax this check cannot read near those
  settings: the migration moves only the default project bank;
- `document:` more than one YAML document.

Usage: python3 omp-settings.py CONFIG_YML    exit 0 when there is no reason
"""
import re
import sys

# OMP 18.5.1's settings declared with `credential: true`.
CREDENTIALS = {
    "auth.broker.token",
    "dev.autoqaPush.token",
    "hindsight.apiToken",
    "images.urls.credentials",
    "mnemopi.embeddingApiKey",
    "mnemopi.llmApiKey",
    "searxng.basicPassword",
    "searxng.token",
}
BANK_SETTINGS = {"mnemopi.bank", "mnemopi.dbPath", "mnemopi.scoping"}
WATCHED = CREDENTIALS | BANK_SETTINGS
KEY = re.compile(r"""^("[^"]*"|'[^']*'|[^\s:{}\[\]#'"][^:{}\[\]#]*?)\s*:(?:\s+(.*?))?\s*$""")


def related(path):
    """Whether a path is a watched setting, lies inside one, or contains one."""
    return any(path == w or path.startswith(w + ".") or w.startswith(path + ".") for w in WATCHED)


def check(text):
    reasons = []
    stack = []  # (indent, key) of the mappings that enclose the current line
    scalar = None  # the indent of a key whose value is a block scalar (| or >)
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.rstrip()
        body = line.lstrip(" ")
        if not body or body.startswith("#"):
            continue
        if scalar is not None and len(line) - len(body) > scalar:
            continue  # text of the block scalar
        scalar = None
        if body in ("---", "..."):
            reasons.append(f"document: line {number}: more than one YAML document is not supported")
            continue
        indent = len(line) - len(body)
        if body.startswith("-"):
            continue  # a list item belongs to the key above it, which was checked
        m = KEY.match(body)
        if not m:
            continue  # the continuation of a multi-line value
        key = m.group(1).strip("'\"")
        value = (m.group(2) or "").split(" #")[0].strip()
        while stack and stack[-1][0] >= indent:
            stack.pop()
        path = ".".join([k for _, k in stack] + [key])
        if value.startswith(("{", "[", "&", "*", "!")) and related(path):
            tag = "bank" if any(b == path or b.startswith(path + ".") for b in BANK_SETTINGS) else "credential"
            reasons.append(f"{tag}: line {number}: {path} uses YAML syntax this check does not read; write it as a block mapping")
        elif path in CREDENTIALS or any(path.startswith(c + ".") for c in CREDENTIALS):
            reasons.append(f"credential: line {number}: {path} is a credential; set it by hand on the new machine")
        elif path in ("mnemopi.bank", "mnemopi.dbPath") and value not in ("", "''", '""', "null", "~"):
            reasons.append(f"bank: line {number}: {path} selects a non-default memory bank; only the default project bank moves")
        elif path == "mnemopi.scoping" and value.strip("'\"") not in ("", "per-project"):
            reasons.append(f"bank: line {number}: mnemopi.scoping is {value}; only per-project scoping is supported")
        if value.startswith(("|", ">")):
            scalar = indent
        elif value == "":
            stack.append((indent, key))
    return reasons


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    found = check(open(sys.argv[1]).read())
    for reason in found:
        print(reason)
    sys.exit(1 if found else 0)
