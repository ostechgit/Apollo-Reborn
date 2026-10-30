#!/usr/bin/env python3
"""Network-local mock contract checks; never contacts Reddit."""
import importlib.util
import json
import pathlib
import sys
import threading
import urllib.error
import urllib.parse
import urllib.request
import unittest
from http.server import ThreadingHTTPServer

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("mock", pathlib.Path(__file__).with_name("mock_reddit_server.py"))
mock = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mock)

class CommentSubmitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), mock.Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def submit(self, target, text, token="mock-user"):
        request = urllib.request.Request(
            f"http://127.0.0.1:{self.server.server_port}/api/comment",
            data=urllib.parse.urlencode({"thing_id": target, "text": text, "api_type": "json"}).encode(),
            headers={"Authorization": f"bearer {token}"})
        with urllib.request.urlopen(request) as response:
            return json.load(response)

    def test_post_and_comment_target_and_unicode(self):
        for target in ["t3_mock", "t1_c001"]:
            text = "Unicode reply — café\nsecond paragraph"
            thing = self.submit(target, text)["json"]["data"]["things"][0]
            self.assertEqual(thing["kind"], "t1")
            self.assertEqual(thing["data"]["parent_id"], target)
            self.assertEqual(thing["data"]["body"], text)

    def test_continue_thread_context(self):
        request = urllib.request.Request(
            f"http://127.0.0.1:{self.server.server_port}/comments/1fx0002/_/c002.json?context=0&limit=100",
            headers={"Authorization": "bearer mock-user"})
        with urllib.request.urlopen(request) as response:
            thread = json.load(response)
        parent = thread[1]["data"]["children"][0]["data"]
        self.assertEqual(parent["name"], "t1_c002")
        child = parent["replies"]["data"]["children"][0]["data"]
        self.assertEqual(child["parent_id"], "t1_c002")
        self.assertEqual(child["body"], "Local continued thread reply")

    def test_parent_context_and_view_all_routes(self):
        def get(path):
            request = urllib.request.Request(
                f"http://127.0.0.1:{self.server.server_port}{path}",
                headers={"Authorization": "bearer mock-user"})
            with urllib.request.urlopen(request) as response:
                return json.load(response)

        focused = get("/comments/1fx0002/_/c002.json?context=2")
        self.assertEqual(focused[1]["data"]["children"][0]["data"]["name"], "t1_c002")
        ancestors = get("/comments/1fx0002/_/c002.json?context=10")
        root = ancestors[1]["data"]["children"][0]["data"]
        self.assertEqual(root["name"], "t1_c001")
        self.assertEqual(root["replies"]["data"]["children"][0]["data"]["name"], "t1_c002")
        full = get("/comments/1fx0002.json")
        self.assertEqual(full[1]["data"]["children"][0]["data"]["name"], "t1_c001")
        with self.assertRaises(urllib.error.HTTPError):
            get("/comments/1fx0002/_/c999.json?context=2")
        with self.assertRaises(urllib.error.HTTPError) as failure:
            get("/comments/errorpost.json")
        self.assertEqual(failure.exception.code, 500)
        empty = get("/comments/emptypost.json")
        self.assertEqual(empty[1]["data"]["children"], [])
        self.assertEqual(empty[0]["data"]["children"][0]["data"]["id"], "emptypost")

    def test_report_payloads(self):
        def post(form):
            request = urllib.request.Request(
                f"http://127.0.0.1:{self.server.server_port}/api/report",
                data=urllib.parse.urlencode(form).encode(),
                headers={"Authorization": "bearer mock-user"})
            with urllib.request.urlopen(request) as response:
                return json.load(response)

        # Admin reason: reason holds the selector name, the sentence goes in site_reason.
        self.assertEqual(post({"thing_id": "t1_x", "reason": "site_reason_selected",
                               "site_reason": "This is spam"}), {})
        # Subreddit rule: reason and rule_reason both carry the rule text.
        self.assertEqual(post({"thing_id": "t1_x", "reason": "Keep it civil",
                               "rule_reason": "Keep it civil"}), {})
        errors = post({"thing_id": "t1_x", "reason": "site_reason_selected"})
        self.assertEqual(errors["json"]["errors"][0][0], "BAD_REASON")
        self.assertTrue(post({"reason": "site_reason_selected", "site_reason": "spam"})["json"]["errors"])

    def test_successful_writes_have_distinct_identity(self):
        first = self.submit("t3_mock", "first")["json"]["data"]["things"][0]["data"]
        second = self.submit("t3_mock", "second")["json"]["data"]["things"][0]["data"]
        self.assertNotEqual(first["id"], second["id"])
        self.assertEqual(first["name"], "t1_" + first["id"])

    def test_json_rejection_and_malformed_fixture(self):
        self.assertEqual(self.submit("t3_mock", "mock-reject")["json"]["errors"][0][0], "RATELIMIT")
        self.assertNotIn("things", self.submit("t3_mock", "mock-malformed")["json"]["data"])
        self.assertTrue(self.submit("invalid", "text")["json"]["errors"])
        self.assertTrue(self.submit("t3_mock", " ")["json"]["errors"])

    def test_app_only_rejected(self):
        with self.assertRaises(urllib.error.HTTPError) as error:
            self.submit("t3_mock", "text", "mock-apponly")
        self.assertEqual(error.exception.code, 403)

if __name__ == "__main__":
    unittest.main()
