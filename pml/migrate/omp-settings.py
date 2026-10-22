"""Check OMP's config.yml before a migration copies it.

OMP reads config.yml with a full YAML parser. This check reads only a small
subset of YAML and reports everything else, so content it cannot classify never
counts as safe:
- block mappings indented with spaces, consistently: `key:` or `key: value`,
  keys made of letters, digits, '_', '.' and '-';
- values on one line: plain words without '#', brackets, commas or quotes,
  single- or double-quoted strings, or `{}` and `[]` (also alone on the next
  line, more indented than their key);
- list items `- value` with such values;
- blank lines and comments.
The file is decoded as UTF-8 with replacement characters, as OMP decodes it.

Each reason is printed on its own line, tagged:
- `credential:` a setting OMP 18.5.1 marks as a credential;
- `bank:` a non-default memory bank (`mnemopi.bank`, `mnemopi.dbPath`, or
  scoping other than per-project): the migration moves only the default bank;
- `syntax:` content outside the subset, which could hide either.

Exit status: 0 nothing to report; 3 reasons printed; anything else means the
check itself failed, and the caller must not copy.

Usage: python3 omp-settings.py CONFIG_YML
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
BANK_SETTINGS = ("mnemopi.bank", "mnemopi.dbPath", "mnemopi.scoping")
UNSET = ("", "~", "null", '""', "''")

KEY = r"[A-Za-z0-9_][A-Za-z0-9_.\-]*"
DQ = r'"(?:[^"\\]|\\.)*"'
SQ = r"'(?:[^']|'')*'"
PLAIN = r"(?:-(?=[0-9])|[A-Za-z0-9_./~+(])[^#{}\[\],\"'\t]*?"
VALUE = rf"(?:{DQ}|{SQ}|\{{\}}|\[\]|{PLAIN})"
COMMENT = r"(?:[ ]+#.*)?"
KEY_LINE = re.compile(rf"^( *)({KEY}):(?:[ ]+({VALUE}))?{COMMENT}$")
ITEM_LINE = re.compile(rf"^( *)-[ ]+({VALUE}){COMMENT}$")
EMPTY_LINE = re.compile(rf"^( *)(\{{\}}|\[\]){COMMENT}$")
CONTROL = re.compile("[\x00-\x08\x0b-\x1f\x7f\x85  ]")


class Node:
    def __init__(self, indent, path, value):
        self.indent, self.path, self.value = indent, path, value
        self.child_indent = None  # the indent of its first child key
        self.kind = None  # "mapping" or "list" once it has children


def plain_ok(value):
    return not value.startswith("- ") and ": " not in value and not value.rstrip().endswith(":")


def setting_reasons(number, path, value):
    """Credential and bank reasons for one setting and its value."""
    found = []
    shown = value.strip("'\"")
    if path in CREDENTIALS or any(path.startswith(c + ".") for c in CREDENTIALS):
        found.append(f"credential: line {number}: {path} is a credential; set it by hand on the new machine")
    if path in ("mnemopi.bank", "mnemopi.dbPath") and value not in UNSET:
        found.append(f"bank: line {number}: {path} selects a non-default memory bank; only the default project bank moves")
    if path == "mnemopi.scoping" and value not in UNSET and shown != "per-project":
        found.append(f"bank: line {number}: mnemopi.scoping is {value}; only per-project scoping is supported")
    if any(path.startswith(b + ".") for b in BANK_SETTINGS):
        found.append(f"bank: line {number}: {path} is not a plain value; only the default project bank moves")
    return found


def check(text):
    reasons = []
    stack = []  # the Nodes that enclose the current line
    last = None  # the Node of the previous key line

    def syntax(number, why):
        reasons.append(f"syntax: line {number}: {why}; this check reads only a simple subset of YAML")

    for number, line in enumerate(text.replace("\r\n", "\n").split("\n"), 1):
        if CONTROL.search(line) or "\t" in line:
            syntax(number, "tab or control character")
            continue
        if not line.strip() or line.lstrip(" ").startswith("#"):
            continue
        key = KEY_LINE.match(line)
        item = None if key else ITEM_LINE.match(line)
        empty = None if key or item else EMPTY_LINE.match(line)
        if empty:
            indent = len(empty.group(1))
            if last is None or last.value != "" or last.kind or indent <= last.indent:
                syntax(number, "a {} or [] that belongs to no key")
                continue
            last.value = empty.group(2)
            reasons.extend(setting_reasons(number, last.path, last.value))
            continue
        if item:
            indent, value = len(item.group(1)), item.group(2)
            while stack and stack[-1].indent > indent:
                stack.pop()
            parent = stack[-1] if stack else None
            if (
                parent is None
                or parent.value != ""
                or parent.kind == "mapping"
                or (value[0] not in "\"'" and not plain_ok(value))
            ):
                syntax(number, "a list item this check does not read")
                continue
            parent.kind = "list"
            reasons.extend(setting_reasons(number, parent.path + ".item", value))
            continue
        if not key:
            syntax(number, "not a key, a list item or a comment")
            continue
        indent, name, value = len(key.group(1)), key.group(2), key.group(3) or ""
        if value and value[0] not in "\"'{[" and not plain_ok(value):
            syntax(number, "a value this check does not read")
            continue
        while stack and stack[-1].indent >= indent:
            stack.pop()
        if stack:
            parent = stack[-1]
            if parent.value != "" or parent.kind == "list":
                syntax(number, f"{name} continues a value or a list (multi-line values are not read)")
                continue
            if parent.child_indent is None:
                parent.child_indent = indent
            elif parent.child_indent != indent:
                syntax(number, "inconsistent indentation")
                continue
            parent.kind = "mapping"
            path = parent.path + "." + name
        elif indent != 0:
            syntax(number, "an indented key with no parent")
            continue
        else:
            path = name
        node = Node(indent, path, value)
        stack.append(node)
        last = node
        reasons.extend(setting_reasons(number, path, value))
    return reasons


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
        found = check(f.read())
    for reason in found:
        print(reason)
    sys.exit(3 if found else 0)
