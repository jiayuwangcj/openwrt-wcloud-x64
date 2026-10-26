#!/usr/bin/env python3
"""Exercise the hotplug hook using fake files and commands, never a router."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


class HotplugTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.trace = self.root / "trace"
        for d in ("sys/class/net/wg-highflow", "var/run/sqm"):
            (self.root / d).mkdir(parents=True)
        (self.root / "sys/class/net/wg-highflow/ifindex").write_text("198\n")
        (self.root / "sys/class/net/wg-highflow/tun_flags").touch()
        (self.root / "var/run/sqm/wg-highflow.state").touch()
        self.functions = self.root / "functions.sh"
        self.functions.write_text('''
config_load() { return 0; }
config_foreach() { "$1" fixture; }
config_get() {
 case "$3" in
 interface) v=wg-highflow;; enabled) v=${QUEUE_ENABLED:-1};;
 qdisc) v=cake;; upload|download) v=56000;; esac
 export "$1=$v"
}
''')
        self.command("sqm-enabled", 'exit "${SERVICE_DISABLED:-0}"')
        self.command("logger", 'echo "log $*" >> "$TRACE"')
        self.command("tc", '''
if [ "${VERIFY_FAIL:-0}" = 1 ]; then exit 0; fi
case "$1" in
 qdisc) echo "qdisc cake 8019: root bandwidth 56Mbit";;
 filter) echo "Egress Redirect to device ifb4wg-highflow";; esac
''')
        self.command("run-sqm", '''
echo "$*" >> "$TRACE"
if [ "$1" = "${FAIL_STEP:-none}" ]; then exit 2; fi
if [ "$1" = stop ] && [ "${REPLACE_DEVICE:-0}" = 1 ]; then
 echo 199 > "$ROOT/sys/class/net/wg-highflow/ifindex"
fi
if [ "$1" = start ]; then exit "${START_STATUS:-0}"; fi
''')
        src = (Path(__file__).resolve().parents[1] /
               "files/etc/hotplug.d/net/30-sqm-highflow").read_text()
        # Only this isolated test copy uses fixture paths and fake commands.
        src = src.replace("/etc/init.d/sqm", str(self.bin / "sqm-enabled"))
        src = src.replace("/lib/functions.sh", str(self.functions))
        src = src.replace("/usr/lib/sqm/run.sh", str(self.bin / "run-sqm"))
        src = src.replace("/sys/class/net/", str(self.root / "sys/class/net") + "/")
        src = src.replace("/var/run/", str(self.root / "var/run") + "/")
        self.hook = self.root / "hook"
        self.hook.write_text(src)

    def command(self, name, body):
        p = self.bin / name
        p.write_text("#!/bin/sh\n" + body + "\n")
        p.chmod(0o700)

    def run_hook(self, **extra):
        env = dict(os.environ, PATH=str(self.bin) + ":/usr/bin:/bin",
                   TRACE=str(self.trace), ROOT=str(self.root),
                   ACTION="add", DEVICENAME="wg-highflow")
        env.update(extra)
        return subprocess.run(["/bin/sh", str(self.hook)], env=env,
                              capture_output=True, text=True, timeout=5)

    def calls(self):
        return self.trace.read_text() if self.trace.exists() else ""

    def test_unrelated_events_and_disabled_configuration_do_nothing(self):
        for env in ({"ACTION": "remove"}, {"DEVICENAME": "pppoe-PPP"},
                    {"DEVICENAME": "ifb4wg-highflow"}, {"SERVICE_DISABLED": "1"},
                    {"QUEUE_ENABLED": "0"}):
            self.assertEqual(self.run_hook(**env).returncode, 0)
            self.assertEqual(self.calls(), "")

    def test_stale_state_repaired_and_duplicate_event_is_noop(self):
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertIn("stop wg-highflow\nstart wg-highflow\n", self.calls())
        self.assertIn("SQMH_READY", self.calls())
        before = self.calls()
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertEqual(self.calls(), before)

    def test_first_creation_without_stale_state_starts_directly(self):
        (self.root / "var/run/sqm/wg-highflow.state").unlink()
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertNotIn("stop wg-highflow", self.calls())
        self.assertIn("start wg-highflow", self.calls())

    def test_native_nonmatching_tail_status_requires_readback_proof(self):
        self.assertEqual(self.run_hook(START_STATUS="1").returncode, 0)
        self.assertIn("native_start_status=1", self.calls())
        (self.root / "var/run/sqm-highflow.last").unlink()
        self.assertNotEqual(self.run_hook(START_STATUS="1", VERIFY_FAIL="1").returncode, 0)

    def test_stop_failure_and_device_replacement_prevent_start(self):
        for env in ({"FAIL_STEP": "stop"}, {"REPLACE_DEVICE": "1"}):
            self.trace.unlink(missing_ok=True)
            (self.root / "sys/class/net/wg-highflow/ifindex").write_text("198\n")
            self.assertNotEqual(self.run_hook(**env).returncode, 0)
            self.assertNotIn("start wg-highflow", self.calls())

    def test_failed_start_or_verification_does_not_mark_success(self):
        for env in ({"FAIL_STEP": "start"}, {"VERIFY_FAIL": "1"}):
            self.assertNotEqual(self.run_hook(**env).returncode, 0)
            self.assertFalse((self.root / "var/run/sqm-highflow.last").exists())
        self.assertIn("SQMH_START", self.calls())
        self.assertIn("SQMH_VERIFY", self.calls())


if __name__ == "__main__":
    unittest.main()
