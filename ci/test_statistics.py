#!/usr/bin/env python3
"""Collector regression checks using local text fixtures only."""
import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "collector_patch", Path(__file__).with_name("patch-sqm-collector.py"))
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


class CollectorPatchTests(unittest.TestCase):
    source = ('jsn=$(tc -s -j qdisc show dev "$ifc") || return\n'
              'echo "PUTVAL \\"host/sqm-iface/qdisc_backlog\\" interval=$INTERVAL N:$backlog"\n'
              'echo "PUTVAL \\"host/sqm-mq/qdisc_backlog\\" interval=$INTERVAL N:$backlog"\n')

    def test_root_and_unknown_value(self):
        result = collector.patch(self.source)
        self.assertIn('qdisc show dev "$ifc" root)', result)
        self.assertIn('N:${backlog:-U}', result)
        self.assertEqual(collector.patch(result), result)

    def test_changed_or_duplicated_source_rejected(self):
        for text in ("", self.source * 2,
                     self.source.replace('N:$backlog', 'N:changed')):
            with self.subTest(text=text), self.assertRaisesRegex(
                    ValueError, "SQM_COLLECTOR_SOURCE_CHANGED"):
                collector.patch(text)


if __name__ == "__main__":
    unittest.main()
