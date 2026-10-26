#!/usr/bin/env python3
"""Apply the two reviewed, read-only SQM collector compatibility fixes."""
import sys
from pathlib import Path


def patch(text):
    replacements = (
        ('jsn=$(tc -s -j qdisc show dev "$ifc") || return',
         'jsn=$(tc -s -j qdisc show dev "$ifc" root) || return', 1),
        ('qdisc_backlog\\" interval=$INTERVAL N:$backlog"',
         'qdisc_backlog\\" interval=$INTERVAL N:${backlog:-U}"', 2),
    )
    for before, after, count in replacements:
        if text.count(after) == count and before not in text:
            continue
        if text.count(before) != count or after in text:
            raise ValueError("SQM_COLLECTOR_SOURCE_CHANGED: review pinned feed collector")
        text = text.replace(before, after)
    return text


if __name__ == "__main__":
    path = Path(sys.argv[1])
    # Validate all replacements before writing; never leave a partial patch.
    original = path.read_text()
    updated = patch(original)
    if updated != original:
        path.write_text(updated)
    print("SQM collector: root-only read and unknown-backlog handling verified.")
