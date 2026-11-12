#!/usr/bin/env python3
"""Validate the public source package without Xcode or third-party packages."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "ARCHIVE-SHA256SUMS.txt"
PUBLIC_DOCS = ["README.md", "RESTORE.md", "CONTRIBUTING.md", "SECURITY.md",
               "THIRD_PARTY_NOTICES.md", "docs/README.md", "docs/FAQ.md",
               "docs/PRIVACY.md", "docs/ROADMAP.md", "docs/ARCHITECTURE.md",
               "docs/REDDIT_POST.md"]
PRIVATE_DIRS = {".build", "DerivedData", "Evidence", "Logs", "xcuserdata",
                ".claude", ".codex", ".xcodebuildmcp"}
PRIVATE_SUFFIXES = {".p8", ".p12", ".pfx", ".pem", ".key", ".mobileprovision",
                    ".provisionprofile", ".ipa", ".log"}
SECRET_MARKERS = [r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
                  r"\bgh[pousr]_[A-Za-z0-9]{30,}\b",
                  r"\bgithub_pat_[A-Za-z0-9_]{50,}\b",
                  r"\bsk_live_[A-Za-z0-9]{20,}\b",
                  r"\bAKIA[A-Z0-9]{16}\b"]


def tracked_files():
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    return sorted(p.decode("utf-8") for p in raw.split(b"\0") if p)


def manifest_for(paths):
    return "".join(f"{hashlib.sha256((ROOT / p).read_bytes()).hexdigest()}  {p}\n"
                   for p in paths if p != MANIFEST)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--update-manifest", action="store_true")
    args = parser.parse_args()
    paths = tracked_files()
    errors = []
    for name in paths:
        path = PurePosixPath(name)
        local = ROOT / name
        if local.is_symlink() or not local.is_file():
            errors.append(f"Missing file or unsupported symlink: {name}")
            continue
        env_private = path.name.startswith(".env") and not path.name.endswith(".example")
        if PRIVATE_DIRS.intersection(path.parts) or path.suffix in PRIVATE_SUFFIXES or env_private or path.name == ".DS_Store":
            errors.append(f"Private/generated file must not be tracked: {name}")
        if local.stat().st_size >= 50 * 1024 * 1024:
            errors.append(f"File exceeds the repository's 50 MiB limit: {name}")
        if path.suffix == ".json":
            try:
                json.loads(local.read_text())
            except (UnicodeError, ValueError) as exc:
                errors.append(f"Invalid JSON: {name}: {exc}")
        try:
            text = local.read_text()
        except UnicodeError:
            continue
        for pattern in SECRET_MARKERS:
            if re.search(pattern, text):
                errors.append(f"Potential credential marker in {name}; inspect locally, do not paste it publicly")
                break

    # Only the maintained public guides are checked. Dated engineering notes
    # deliberately reference private Evidence artifacts omitted from this repo.
    for name in PUBLIC_DOCS:
        file = ROOT / name
        if not file.is_file():
            errors.append(f"Missing public guide: {name}")
            continue
        text = file.read_text()
        links = re.findall(r"\]\(([^\s)]+)(?:\s+[^)]*)?\)", text)
        links += re.findall(r'(?:src|href)="([^"]+)"', text)
        for link in links:
            url = urlsplit(link.strip("<>"))
            if url.scheme or url.netloc or not url.path:
                continue
            target = (file.parent / unquote(url.path)).resolve()
            if not target.is_relative_to(ROOT) or not target.exists():
                errors.append(f"Broken or out-of-repository link in {name}: {link}")

    if errors:
        raise SystemExit("\n".join(errors))
    expected = manifest_for(paths)
    if args.update_manifest:
        (ROOT / MANIFEST).write_text(expected)
        print(f"Updated {MANIFEST} for {len(paths) - (MANIFEST in paths)} files. Stage it before committing.")
    elif not (ROOT / MANIFEST).is_file() or (ROOT / MANIFEST).read_text() != expected:
        raise SystemExit("Manifest differs. Stage intended files, run --update-manifest, then stage the manifest.")
    print(f"Repository checks passed: {len(paths)} tracked files; public links, JSON and privacy guards checked.")


if __name__ == "__main__":
    main()
