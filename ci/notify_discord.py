#!/usr/bin/env python3
"""Send allowlisted workflow metadata only; never forward logs or commit text."""
import json
import os
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

WORKFLOWS = {
    "OpenWrt CI": "OpenWrt CI",
    "Build OpenWrt": "OpenWrt 固件构建",
    "Check upstream stable release": "OpenWrt 上游检查",
}
JOBS = {
    "Checks": "检查",
    "Build firmware": "构建",
    "Publish release": "发布",
    "Publish verified firmware release": "发布",
    "build": "构建",
    "check": "检查",
}
STATES = {
    "success": "成功", "failure": "失败", "cancelled": "已取消",
    "timed_out": "超时", "skipped": "已跳过", "neutral": "中立",
    "action_required": "需要处理", "queued": "排队中",
    "pending": "等待中", "in_progress": "运行中", "stale": "已过期",
}


def validate_webhook(url):
    parts = urlsplit(url)
    if (parts.scheme != "https" or parts.netloc != "discord.com"
            or not re.fullmatch(r"/api(?:/v\d+)?/webhooks/\d+/[A-Za-z0-9._-]+", parts.path)
            or parts.fragment):
        raise ValueError("Invalid Discord webhook configuration")


def build_message(event, repository, jobs=()):
    run = event.get("workflow_run", {})
    workflow = WORKFLOWS.get(run.get("name"))
    action = event.get("action")
    if not workflow or action not in ("requested", "in_progress", "completed"):
        return None
    if run.get("repository", {}).get("full_name") != repository:
        raise ValueError("Workflow repository mismatch")
    run_id = run.get("id")
    if not isinstance(run_id, int) or run_id <= 0:
        raise ValueError("Invalid workflow run ID")
    status = {"requested": "已排队", "in_progress": "开始执行"}.get(
        action, STATES.get(run.get("conclusion"), "已结束"))
    lines = [f"状态：{status}"]
    if action == "completed":
        for job in jobs:
            label = JOBS.get(job.get("name"))
            if label:
                state = STATES.get(job.get("conclusion") or job.get("status"), "未知")
                lines.append(f"{label}：{state}")
        if any(JOBS.get(j.get("name")) == "发布" and j.get("conclusion") == "success" for j in jobs):
            lines.append(f"[下载 Release](https://github.com/{repository}/releases)")
    color = 0x2ECC71 if run.get("conclusion") == "success" else (
        0xE74C3C if run.get("conclusion") in ("failure", "timed_out") else 0x3498DB)
    phase = {"requested": "CI 排队", "in_progress": "CI 开始", "completed": "CI 结束"}[action]
    project = repository.split("/", 1)[1]
    return {
        "allowed_mentions": {"parse": []},
        "embeds": [{"title": f"[{phase}] {project} · {workflow}", "description": "\n".join(lines),
                    "url": f"https://github.com/{repository}/actions/runs/{run_id}",
                    "color": color}],
    }


def fetch_jobs(repository, run_id, token):
    request = Request(
        f"https://api.github.com/repos/{repository}/actions/runs/{run_id}/jobs?filter=latest&per_page=100",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json",
                 "User-Agent": "openwrt-ci-notifier"})
    with urlopen(request, timeout=15) as response:
        return json.load(response).get("jobs", [])


def deliver(webhook, message):
    validate_webhook(webhook)
    request = Request(webhook, data=json.dumps(message).encode(), method="POST",
                      headers={"Content-Type": "application/json", "User-Agent": "openwrt-ci-notifier"})
    for attempt in range(3):
        try:
            with urlopen(request, timeout=15) as response:
                response.read()
            return
        except HTTPError as error:
            # Discord response bodies and exception URLs can contain credentials.
            code = error.code
            error.close()
            if attempt < 2 and (code == 429 or code >= 500):
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(f"Discord delivery failed (HTTP {code})") from None
        except (URLError, TimeoutError, OSError):
            raise RuntimeError("Discord delivery failed (network error)") from None


def main():
    webhook = os.environ.get("DISCORD_CI_WEBHOOK_URL")
    if not webhook:
        print("::notice::Discord CI notifications are not configured.")
        return
    repository = os.environ["GITHUB_REPOSITORY"]
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Invalid repository")
    with open(os.environ["GITHUB_EVENT_PATH"], encoding="utf-8") as stream:
        event = json.load(stream)
    message = build_message(event, repository)
    if message is None:
        return
    jobs = ()
    if event["action"] == "completed":
        jobs = fetch_jobs(repository, event["workflow_run"]["id"], os.environ["GITHUB_TOKEN"])
        message = build_message(event, repository, jobs)
    deliver(webhook, message)
    print("Discord CI notification sent.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # Never emit arbitrary exception text, URLs, event bodies or credentials.
        if isinstance(error, RuntimeError) and str(error).startswith("Discord delivery failed ("):
            print(f"::error::{error}", file=sys.stderr)
        else:
            print("::error::CI notification failed; inspect configuration and permissions.", file=sys.stderr)
        sys.exit(1)
