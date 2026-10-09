"""Distribution boundary tests; no production state or network access."""
import gzip
import importlib.util
import io
import tarfile
import tempfile
import unittest
import subprocess
import json
import os
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("release", Path(__file__).resolve().parents[1] / "scripts/release.py")
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class DistributionTests(unittest.TestCase):
    def test_normalizes_identity_timestamp_and_pax_metadata_reproducibly(self):
        with tempfile.TemporaryDirectory() as folder:
            first, second = Path(folder) / "first.tgz", Path(folder) / "second.tgz"
            entries = [("package/b.txt", b"hello\n", 0o644), ("package/a.sh", b"echo ok\n", 0o755)]
            release.write_archive(first, entries, 1234567890)
            release.write_archive(second, list(reversed(entries)), 1234567890)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            self.assertEqual(first.read_bytes()[4:8], bytes(4))  # gzip mtime
            with tarfile.open(first) as archive:
                self.assertEqual(archive.getnames(), ["package/a.sh", "package/b.txt"])
                for entry in archive:
                    self.assertEqual((entry.uid, entry.gid, entry.uname, entry.gname), (0, 0, "root", "root"))
                    self.assertEqual(entry.mtime, 1234567890)
                    self.assertEqual(entry.pax_headers, {})
            release.check_archive(first)

    def test_blocks_user_state_assets_and_path_traversal(self):
        for path in ["package/.env", "package/.local/state.json", "package/node_modules/x.js",
                     "package/DSH Notify.app/Contents/Info.plist", "package/icon.icns",
                     "package/session-menu.json", "../escape", "/absolute/file", "package/a/../b"]:
            with self.subTest(path=path), self.assertRaises(release.ReleaseError):
                release.check_path(path)

    def test_blocks_private_content_without_printing_it(self):
        fixtures = [b"/Users/" + b"example/private", b"session-" + b"12345678-1234-abcd-1234-123456789abc",
                    b"ghp_" + b"a" * 35, b"sk-proj-" + b"b" * 40,
                    b"-----BEGIN " + b"OPENSSH PRIVATE KEY-----"]
        for data in fixtures:
            with self.subTest(kind=data[:4]), self.assertRaises(release.ReleaseError) as caught:
                release.check_content(data, "fixture")
            self.assertNotIn(data.decode(), str(caught.exception))

    def test_rejects_links_before_extraction(self):
        output = io.BytesIO()
        with tarfile.open(fileobj=output, mode="w") as archive:
            entry = tarfile.TarInfo("package/link")
            entry.type = tarfile.SYMTYPE
            entry.linkname = "../../outside"
            archive.addfile(entry)
        with self.assertRaises(release.ReleaseError):
            release.read_entries(output.getvalue())

    def test_detects_identifying_archive_headers(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "unsafe.tgz"
            with tarfile.open(path, "w:gz") as archive:
                entry = tarfile.TarInfo("package/README.md")
                entry.uid, entry.gid, entry.uname = 501, 20, "local-builder"
                entry.size = 2
                archive.addfile(entry, io.BytesIO(b"ok"))
            with self.assertRaises(release.ReleaseError):
                release.check_archive(path)

    def test_accepts_licenses_fonts_and_public_install_paths(self):
        release.check_path("package/macos/assets/vendor/katex/fonts/font.woff2")
        release.check_content(b"~/Applications/DSH Notify.app; github:owner/repo#main; MIT", "README.md")
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "font.tgz"
            release.write_archive(path, [("package/font.woff2", bytes(range(256)), 0o644)], 0)
            release.check_archive(path)

    def test_long_paths_round_trip_without_identifying_extensions(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "long.tgz"
            name = "package/" + "nested/" * 20 + "README.md"
            release.write_archive(path, [(name, b"ok", 0o644)], 1)
            self.assertEqual(release.read_entries(path.read_bytes()), [(name, b"ok", 0o644)])
            release.check_archive(path)

    def test_history_audit_catches_removed_secrets(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            def git(*args):
                return subprocess.check_output(["git", "-c", "user.name=Release Test", "-c",
                    "user.email=release-test@users.noreply.github.com", *args], cwd=root, stderr=subprocess.PIPE)
            git("init", "-q")
            (root / "README.md").write_text("public\n")
            git("add", "."); git("commit", "-qm", "Clean source")
            self.assertEqual(release.audit_repository(root)["findings"], 0)
            (root / "README.md").write_text("ghp_" + "c" * 40)
            git("add", "."); git("commit", "-qm", "Unsafe history fixture")
            (root / "README.md").write_text("public again\n")
            git("add", "."); git("commit", "-qm", "Remove fixture")
            with self.assertRaises(release.ReleaseError):
                release.audit_repository(root)

    def test_history_audit_accepts_github_web_identity_and_rejects_personal_email(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            def git(*args, committer="release-test@users.noreply.github.com"):
                env = dict(os.environ, GIT_COMMITTER_NAME="Release Test", GIT_COMMITTER_EMAIL=committer)
                return subprocess.check_output(["git", "-c", "user.name=Release Test", "-c",
                    "user.email=release-test@users.noreply.github.com", *args], cwd=root,
                    stderr=subprocess.PIPE, env=env)
            git("init", "-q")
            (root / "README.md").write_text("public\n")
            git("add", ".")
            # GitHub records its own identity as committer for web-interface edits.
            git("commit", "-qm", "Edit through the GitHub web interface", committer="noreply@github.com")
            self.assertEqual(release.audit_repository(root)["commitEmailPolicy"], "github-noreply")
            git("commit", "-q", "--amend", "-m", "Committer leaks a personal address",
                committer="person@example.com")
            with self.assertRaises(release.ReleaseError):
                release.audit_repository(root)

    def test_history_audit_catches_private_path_renamed_without_content_change(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            def git(*args):
                return subprocess.check_output(["git", "-c", "user.name=Release Test", "-c",
                    "user.email=release-test@users.noreply.github.com", *args], cwd=root, stderr=subprocess.PIPE)
            git("init", "-q")
            (root / ".env").write_text("non-pattern private setting\n")
            git("add", "."); git("commit", "-qm", "Private filename fixture")
            git("mv", ".env", "README.md"); git("commit", "-qm", "Same blob, public filename")
            with self.assertRaises(release.ReleaseError):
                release.audit_repository(root)

    def test_plugin_allowlist_excludes_generated_python_cache(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            config = json.loads((release.ROOT / "package.json").read_text())
            (root / "package.json").write_text(json.dumps({"name":"notify-package-fixture", "version":"1.0.0", "files":config['files']}))
            (root / ".gitignore").write_text((release.ROOT / ".gitignore").read_text())
            (root / "scripts/__pycache__").mkdir(parents=True)
            (root / "scripts/tool.py").write_text("print('public source')\n")
            (root / "scripts/__pycache__/tool.cpython-311.pyc").write_bytes(b"generated cache")
            npm = os.environ.get("DSH_RELEASE_TEST_NPM", "npm")
            packed = subprocess.check_output([npm,"pack","--dry-run","--ignore-scripts","--json"], cwd=root, stderr=subprocess.PIPE)
            paths = [f['path'] for f in json.loads(packed)[0]['files']]
            self.assertIn("scripts/tool.py", paths)
            self.assertFalse(any('__pycache__' in path or path.endswith('.pyc') for path in paths), paths)


if __name__ == "__main__":
    unittest.main()
