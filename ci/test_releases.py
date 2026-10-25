#!/usr/bin/env python3
"""Exercise tag/source binding and publication guards without GitHub writes."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parent
SOURCE = "a" * 40
TAG = "v25.12.6-x86-64-123"
IMAGE = "openwrt-x86-64-generic-squashfs-combined.img.gz"
MOCK_GH = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ["MOCK_CALLS"], "a") as output:
    output.write(json.dumps(args) + "\n")
state = Path(os.environ["MOCK_TAG"])
if args[0] == "api":
    if os.environ.get("MOCK_API_ERROR"):
        sys.exit(42)
    if "POST" in args:
        source = next(a[4:] for a in args if a.startswith("sha="))
        state.write_text("commit " + source)
    if state.exists():
        print(state.read_text())
elif args[:2] not in (["release", "create"], ["release", "edit"]):
    sys.exit(99)
'''


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        binary = self.root / "gh"
        binary.write_text(MOCK_GH)
        binary.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{self.root}:{os.environ['PATH']}",
                        GH_TOKEN="test", GITHUB_REPOSITORY="example/router",
                        GITHUB_SHA=SOURCE, GITHUB_RUN_ID="123", GITHUB_RUN_ATTEMPT="1",
                        OPENWRT_REF="v25.12.6", OPENWRT_COMMIT="upstream",
                        GITHUB_STEP_SUMMARY=str(self.root / "summary"),
                        MOCK_TAG=str(self.root / "tag"), MOCK_CALLS=str(self.root / "calls"))
        self.firmware = self.root / "firmware"
        self.firmware.mkdir()
        data = b"verified firmware fixture\n"
        (self.firmware / IMAGE).write_bytes(data)
        (self.firmware / "openwrt-x86-64-generic.manifest").write_text("sqm-scripts - test\n")
        (self.firmware / "sha256sums").write_text(
            f"{hashlib.sha256(data).hexdigest()}  {IMAGE}\n")
        (self.firmware / "build-provenance.txt").write_text(
            f"Configuration commit: {SOURCE}\nOpenWrt: v25.12.6 (upstream)\n")

    def run_script(self, script, *args):
        return subprocess.run(["bash", str(SCRIPTS / script), *map(str, args)],
                              env=self.env, text=True, capture_output=True, check=False)

    def calls(self):
        path = self.root / "calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def set_tag(self, source=SOURCE):
        (self.root / "tag").write_text(f"commit {source}")

    def test_reservation_is_exact_and_stable_across_job_retries(self):
        for attempt in ("1", "2"):
            self.env["GITHUB_RUN_ATTEMPT"] = attempt
            result = self.run_script("release-tag.sh", "prepare")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), TAG)
        writes = [call for call in self.calls() if "POST" in call]
        self.assertEqual(len(writes), 1)
        self.assertIn(f"ref=refs/tags/{TAG}", writes[0])
        self.assertIn(f"sha={SOURCE}", writes[0])

    def test_existing_tag_for_another_source_is_never_moved(self):
        self.set_tag("b" * 40)
        for mode in ("prepare", "verify"):
            self.assertNotEqual(self.run_script("release-tag.sh", mode).returncode, 0)
        self.assertFalse(any("POST" in call for call in self.calls()))

    def test_publication_cannot_create_a_missing_tag(self):
        result = self.run_script("publish-release.sh", self.firmware)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any("POST" in call or call[0] == "release" for call in self.calls()))

    def test_api_failure_does_not_fall_back_to_a_moving_branch(self):
        self.env["MOCK_API_ERROR"] = "1"
        result = self.run_script("release-tag.sh", "prepare")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any("POST" in call for call in self.calls()))

    def test_publication_uses_verified_existing_tag_without_target(self):
        self.set_tag()
        (self.firmware / "private.apk").write_text("do not upload")
        (self.firmware / "openwrt-x86-64-generic-ext4-combined.img.gz").write_text("unused")
        result = self.run_script("publish-release.sh", self.firmware)
        self.assertEqual(result.returncode, 0, result.stderr)
        create = next(call for call in self.calls() if call[:2] == ["release", "create"])
        self.assertEqual(create[2], TAG)
        self.assertIn("--verify-tag", create)
        self.assertIn("--draft", create)
        self.assertNotIn("--target", create)
        self.assertIn(IMAGE, create)
        self.assertNotIn("private.apk", create)
        self.assertNotIn("openwrt-x86-64-generic-ext4-combined.img.gz", create)
        self.assertEqual(self.calls()[-1][:3], ["release", "edit", TAG])

    def test_corrupt_firmware_or_wrong_tag_cannot_be_published(self):
        self.set_tag("b" * 40)
        self.assertNotEqual(self.run_script("publish-release.sh", self.firmware).returncode, 0)
        self.assertFalse(any(call[0] == "release" for call in self.calls()))
        (self.root / "calls").unlink()
        self.set_tag()
        (self.firmware / IMAGE).write_text("corrupt")
        self.assertNotEqual(self.run_script("publish-release.sh", self.firmware).returncode, 0)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
