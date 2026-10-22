#!/usr/bin/env python3
"""Register Home Manager's remote extensions without owning VS Code's registry."""

import argparse
import copy
import json
import os
from pathlib import Path
import re
import stat
import tempfile


def entries(value, description):
    if not isinstance(value, list):
        raise ValueError(f"{description} must be a JSON array")
    for entry in value:
        if not isinstance(entry, dict):
            raise ValueError(f"{description} contains a non-object entry")
        identifier = entry.get("identifier", {}).get("id")
        location = entry.get("location", {})
        if (
            not isinstance(identifier, str)
            or not re.fullmatch(r"[\w-]+\.[\w-]+", identifier, re.ASCII)
            or not isinstance(entry.get("version"), str)
            or not isinstance(location, dict)
            or location.get("scheme") != "file"
            or not isinstance(location.get("path"), str)
            or not Path(location["path"]).is_absolute()
            or not isinstance(entry.get("metadata", {}), dict)
        ):
            raise ValueError(f"{description} contains an invalid extension entry")
    return value


def initial_entries(root):
    """Preserve manually installed extensions when no registry exists yet."""
    result = []
    for directory in sorted(root.iterdir()) if root.exists() else []:
        if directory.name.startswith(".") or not directory.is_dir():
            continue
        manifest = directory / "package.json"
        if not manifest.is_file():
            continue
        package = json.loads(manifest.read_text())
        result.append(
            {
                "identifier": {"id": f"{package['publisher']}.{package['name']}"},
                "version": package["version"],
                "location": {"$mid": 1, "path": str(directory), "scheme": "file"},
                "relativeLocation": directory.name,
                "metadata": package.get("__metadata", {}),
            }
        )
    return entries(result, "Installed extension manifests")


def register(root, desired_path):
    root = Path(os.path.abspath(root))
    namespace = root / ".nix-home"
    registry = root / "extensions.json"
    # Do not follow another manager's registry or redirect our ownership scope.
    if any(path.is_symlink() for path in (root, namespace, registry)):
        raise ValueError("Extensions directory, owned namespace and registry must not be symlinks")
    desired = entries(json.loads(Path(desired_path).read_text()), "Desired extensions")
    identifiers = [entry["identifier"]["id"].lower() for entry in desired]
    if len(set(identifiers)) != len(identifiers):
        raise ValueError("Desired extensions contain duplicate IDs")

    current = (
        entries(json.loads(registry.read_text()), "Existing registry")
        if registry.exists()
        else initial_entries(root)
    )
    managed = []
    for entry in desired:
        identifier = entry["identifier"]["id"]
        source = Path(entry["location"]["path"])
        link = namespace / identifier
        if not link.is_symlink() or link.resolve(strict=True) != source.resolve(strict=True):
            raise ValueError(f"Home Manager link does not match the declared source: {identifier}")
        manifest = json.loads((source / "package.json").read_text())
        if (
            f"{manifest['publisher']}.{manifest['name']}".lower() != identifier.lower()
            or manifest["version"] != entry["version"]
        ):
            raise ValueError(f"Extension manifest does not match its declaration: {identifier}")
        registered = copy.deepcopy(entry)
        registered.pop("relativeLocation", None)
        registered["location"] = {"$mid": 1, "path": str(link), "scheme": "file"}
        registered.setdefault("metadata", {})["pinned"] = True
        managed.append(registered)

    def owned(entry):
        path = Path(os.path.abspath(entry["location"]["path"]))
        return path.is_relative_to(namespace)

    merged = [
        entry
        for entry in current
        if not owned(entry) and entry["identifier"]["id"].lower() not in identifiers
    ] + managed
    if registry.exists() and merged == current:
        return False
    root.mkdir(parents=True, exist_ok=True)
    old_mode = stat.S_IMODE(registry.stat().st_mode) if registry.exists() else 0o600
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=root, prefix=".extensions-", delete=False) as output:
            temporary = output.name
            json.dump(merged, output, indent=2)
            output.write("\n")
            output.flush()
            os.fchmod(output.fileno(), old_mode)
        os.replace(temporary, registry)
    finally:
        if temporary is not None and os.path.exists(temporary):
            os.unlink(temporary)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("extensions_directory", type=Path)
    parser.add_argument("desired", type=Path)
    args = parser.parse_args()
    try:
        changed = register(args.extensions_directory, args.desired)
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        parser.exit(1, f"Remote VS Code extensions: {error}\n")
    print(f"Remote VS Code extensions: {'updated' if changed else 'unchanged'}")


if __name__ == "__main__":
    main()
