#!/usr/bin/env python3
import json
import unittest
from unittest.mock import patch
from urllib.error import URLError

import notify_discord as notifier


class NotificationTests(unittest.TestCase):
    def event(self, action="completed"):
        return {"action": action, "workflow_run": {
            "id": 123, "name": "OpenWrt CI", "conclusion": "success",
            "repository": {"full_name": "example/router"},
            "head_commit": {"message": "PRIVATE_COMMIT_TEXT"},
            "actor": {"login": "PRIVATE_USER"},
            "html_url": "https://untrusted.invalid/PRIVATE_LINK",
            "logs": "PRIVATE_LOGS", "head_branch": "PRIVATE_BRANCH"}}

    def test_private_fields_and_unknown_job_names_are_not_forwarded(self):
        message = notifier.build_message(self.event(), "example/router", [
            {"name": "Checks", "conclusion": "success"},
            {"name": "Publish release", "conclusion": "skipped"},
            {"name": "PRIVATE_JOB_NAME", "conclusion": "failure"}])
        encoded = json.dumps(message)
        self.assertNotIn("PRIVATE_", encoded)
        self.assertTrue(message["embeds"][0]["title"].startswith("[CI 结束] router"))
        self.assertEqual(message["allowed_mentions"], {"parse": []})
        self.assertIn("发布：已跳过", message["embeds"][0]["description"])
        self.assertEqual(message["embeds"][0]["url"],
                         "https://github.com/example/router/actions/runs/123")

    def test_start_and_queue_events(self):
        for action, expected in [("requested", "已排队"), ("in_progress", "开始执行")]:
            message = notifier.build_message(self.event(action), "example/router")
            self.assertIn(expected, message["embeds"][0]["description"])
            phase = "CI 开始" if action == "in_progress" else "CI 排队"
            self.assertTrue(message["embeds"][0]["title"].startswith(f"[{phase}] router"))

    def test_repository_mismatch_is_rejected(self):
        with self.assertRaises(ValueError):
            notifier.build_message(self.event(), "another/repository")

    def test_unknown_workflow_is_ignored(self):
        event = self.event()
        event["workflow_run"]["name"] = "Unrelated workflow"
        self.assertIsNone(notifier.build_message(event, "example/router"))

    def test_webhook_host_is_restricted(self):
        with self.assertRaises(ValueError):
            notifier.validate_webhook("https://untrusted.invalid/api/webhooks/1/fake")

    def test_network_error_does_not_expose_secret_url(self):
        url = "https://discord.com/api/webhooks/1/PRIVATE_TOKEN?thread_id=2&wait=true"
        with patch.object(notifier, "urlopen", side_effect=URLError(url)):
            with self.assertRaisesRegex(RuntimeError, "network error") as raised:
                notifier.deliver(url, {"allowed_mentions": {"parse": []}})
        self.assertNotIn("PRIVATE_TOKEN", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
