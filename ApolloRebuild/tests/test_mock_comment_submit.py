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
