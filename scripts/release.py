#!/usr/bin/env python3
"""Maintainer-only, standard-library distribution builder (Python 3.9+)."""
import argparse
import gzip
import hashlib
import io
import json
import plistlib
import re
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = [
    re.compile(rb"/Users/[A-Za-z0-9_.-]+/"),
    re.compile(rb"session-[0-9a-f]{8}-[0-9a-f]{4}-", re.I),
    re.compile(rb"(?:ghp_|gho_|github_pat_)[A-Za-z0-9_]{20,}"),
    re.compile(rb"sk-(?:proj-)?[A-Za-z0-9_-]{24,}"),
    re.compile(rb"AKIA[A-Z0-9]{16}"),
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
]
PRIVATE_NAMES = {".git", ".local", ".superpowers", "node_modules", "dist", ".DS_Store", "__pycache__",
                 "session-menu.json", "menu-commands", "menu-results", "desktop-jump-status.md", "native-actions-ledger.json"}


class ReleaseError(Exception):
    pass


def run(*args, cwd=ROOT):
    # Never echo subprocess output on failure: installer/metadata output can be private.
    result = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise ReleaseError("Command failed: " + args[0])
    return result.stdout


def check_path(name):
    parts = PurePosixPath(name).parts
    if not parts or name.startswith("/") or "\\" in name or ".." in parts:
        raise ReleaseError("Unsafe archive path")
    if any(p in PRIVATE_NAMES or p.startswith(".env") or p.endswith((".app", ".icns", ".log", ".tgz", ".tar", ".tar.gz", ".zip", ".7z", ".dmg", ".pkg", ".p12")) for p in parts):
        raise ReleaseError("Private or generated artifact in distribution")


def check_content(data, label):
    if any(pattern.search(data) for pattern in PRIVATE):
        raise ReleaseError("Private material detected in " + label)


def read_entries(data):
    entries, seen = [], set()
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as archive:
        for entry in archive:
            check_path(entry.name)
            if entry.isdir():
                continue
            if not entry.isfile() or entry.name in seen:
                raise ReleaseError("Archive links or duplicate paths are not supported")
            seen.add(entry.name)
            content = archive.extractfile(entry).read()
            check_content(content, entry.name)
            entries.append((entry.name, content, 0o755 if entry.mode & 0o111 else 0o644))
    return entries


def write_archive(path, entries, epoch):
    with Path(path).open("xb") as output:
        with gzip.GzipFile(fileobj=output, mode="wb", filename="", mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w", format=tarfile.GNU_FORMAT) as archive:
                for name, data, mode in sorted(entries):
                    check_path(name)
                    check_content(data, name)
                    entry = tarfile.TarInfo(name)
                    entry.size, entry.mode, entry.mtime = len(data), mode, epoch
                    entry.uid, entry.gid, entry.uname, entry.gname = 0, 0, "root", "root"
                    archive.addfile(entry, io.BytesIO(data))


def check_archive(path):
    entries = read_entries(Path(path).read_bytes())
    with tarfile.open(path, "r:gz") as archive:
        for entry in archive:
            if (entry.uid, entry.gid, entry.uname, entry.gname) != (0, 0, "root", "root"):
                raise ReleaseError("Identifying archive ownership metadata")
            if entry.mode not in (0o644, 0o755) or entry.pax_headers or not entry.isfile():
                raise ReleaseError("Unexpected archive metadata")
    return len(entries)


def audit_repository(root=ROOT):
    # Object enumeration deduplicates blobs and returns only one representative name.
    # Inspect every commit's root tree, including deleted/renamed private filenames.
    trees = set(run("git", "log", "--all", "--format=%T", cwd=root).splitlines())
    for tree in sorted(trees):
        for entry in run("git", "ls-tree", "-rz", "--full-tree", tree.decode("ascii"), cwd=root).split(b"\0"):
            if entry:
                check_path(entry.split(b"\t", 1)[1].decode("utf-8"))
    objects = run("git", "rev-list", "--objects", "--all", cwd=root).splitlines()
    ids = []
    for line in objects:
        oid, _, name = line.partition(b" ")
        ids.append(oid)
        if name:
            check_path(name.decode("utf-8"))
    # Batch reads avoid one process per historic blob. Report hashes, never offending content.
    process = subprocess.run(["git", "cat-file", "--batch"], cwd=root, input=b"\n".join(ids) + b"\n",
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if process.returncode:
        raise ReleaseError("Could not inspect Git history")
    stream, blobs = io.BytesIO(process.stdout), 0
    for oid in ids:
        header = stream.readline().split()
        if len(header) != 3:
            raise ReleaseError("Invalid Git object result")
        data = stream.read(int(header[2]))
        if stream.read(1) != b"\n":
            raise ReleaseError("Invalid Git object boundary")
        if header[1] in (b"blob", b"commit", b"tag"):
            check_content(data, "Git object " + oid.decode("ascii"))
        if header[1] == b"blob":
            blobs += 1
    emails = set(run("git", "log", "--all", "--format=%ae%n%ce", cwd=root).decode().splitlines())
    if any(not email.endswith("@users.noreply.github.com") for email in emails):
        raise ReleaseError("Git history contains a non-noreply commit email; review before sharing")
    return {"commits": int(run("git", "rev-list", "--all", "--count", cwd=root)), "blobs": blobs,
            "commitEmailPolicy": "github-noreply", "findings": 0}


def build(output):
    if run("git", "status", "--porcelain", "--untracked-files=normal").strip():
        raise ReleaseError("Commit source changes before building an exact-commit distribution")
    output = Path(output).resolve()
    if output.exists():
        raise ReleaseError("Output directory exists; choose a new directory to preserve earlier evidence")
    commit = run("git", "rev-parse", "HEAD").decode().strip()
    epoch = int(run("git", "show", "-s", "--format=%ct", "HEAD"))
    package = json.loads(run("git", "show", "HEAD:package.json"))
    version, name = package["version"], package["name"]
    if name != "dsh-macos-notify" or not re.fullmatch(r"\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?", version):
        raise ReleaseError("Unexpected package name/version")
    privacy = audit_repository()
    source = read_entries(run("git", "archive", "--format=tar", "HEAD"))
    committed = {path: data for path, data, _ in source}
    for required in ["package-lock.json", "npm-shrinkwrap.json", ".github/workflows/ci.yml", "tests/install.test.mjs"]:
        if required not in committed:
            raise ReleaseError("Incomplete full source archive")
    # npm chooses the plugin allowlist; compare every byte with the committed source.
    with tempfile.TemporaryDirectory(prefix="dsh-notify-pack-") as staging:
        result = json.loads(run("npm", "pack", "--ignore-scripts", "--json", "--pack-destination", staging))[0]
        plugin = read_entries((Path(staging) / result["filename"]).read_bytes())
    for path, data, _ in plugin:
        if not path.startswith("package/") or committed.get(path[len("package/"):]) != data:
            raise ReleaseError("Plugin package differs from the source commit: " + path)
    plist = plistlib.loads(committed["macos/Info.plist"])
    if plist["CFBundleShortVersionString"] != version:
        raise ReleaseError("Plugin/helper version mismatch")
    output.mkdir(parents=True)
    artifacts = {}
    for filename, entries, kind in [
        (name + "-" + version + ".tgz", plugin, "dsh-plugin"),
        (name + "-" + version + "-source.tar.gz", [(name + "-" + version + "/" + p, d, m) for p, d, m in source], "complete-source")
    ]:
        path = output / filename
        write_archive(path, entries, epoch)
        artifacts[filename] = {"kind": kind, "files": check_archive(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    manifest = {"schema": 1, "name": name, "version": version, "helperBuild": plist["CFBundleVersion"],
                "sourceCommit": commit, "sourceEpoch": epoch, "artifacts": artifacts, "privacy": privacy,
                "officialIconIncluded": False, "prebuiltHelperIncluded": False}
    metadata = output / "release-manifest.json"
    metadata.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    sums = {filename: detail["sha256"] for filename, detail in artifacts.items()}
    sums[metadata.name] = hashlib.sha256(metadata.read_bytes()).hexdigest()
    (output / "SHA256SUMS").write_text("".join(digest + "  " + filename + "\n" for filename, digest in sorted(sums.items())))
    print(json.dumps(manifest, indent=2, sort_keys=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", action="store_true", help="Audit all locally reachable Git history without writing")
    parser.add_argument("--output", default="dist/release", help="New output directory for both archives and checksums")
    args = parser.parse_args()
    try:
        if args.audit:
            print(json.dumps(audit_repository(), sort_keys=True))
        else:
            build(args.output)
    except (ReleaseError, OSError, ValueError, tarfile.TarError) as error:
        print("Release validation failed: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
