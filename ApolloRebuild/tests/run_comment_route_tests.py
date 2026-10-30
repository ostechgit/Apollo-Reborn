#!/usr/bin/env python3
"""Compile the actual Foundation-only permalink parser, no app/network."""
import pathlib
import subprocess
import tempfile
source = (pathlib.Path(__file__).resolve().parents[1] / 'Sources/SceneDelegate.swift').read_text()
parser = source[source.index('struct RedditCommentRoute {'):source.index('    @discardableResult')]
tests = r'''
}
func parse(_ text: String) -> RedditCommentRoute? { RedditCommentRoute(url: URL(string: text)!) }
let route = parse("https://www.reddit.com/r/test/comments/abc/title/def/?context=0")!
assert(route.postID == "abc" && route.commentID == "def" && route.context == 0)
assert(parse("https://old.reddit.com/comments/abc/_/def")?.context == nil)
assert(parse("https://reddit.com/comments/abc")?.commentID == nil)
assert(parse("https://reddit.com/r/test/comments/abc/title")?.postID == "abc")
for text in ["https://reddit.com.evil.test/comments/abc/_/def", "https://evil.test/comments/abc/_/def",
             "https://reddit.com/user/comments/abc", "https://reddit.com/comments/abc/_/def/extra",
             "https://reddit.com/comments/abc/_/def?context=-1", "https://reddit.com/comments/abc/_/def?context=x",
             "https://reddit.com/comments/abc/_/def?context=1&context=2", "https://reddit.com/comments/a%2Fb/_/def",
             "apollo://reddit.com/comments/abc/_/def", "https://reddit.com/comments/abc/_/def?context=999999999999999999999"] {
    assert(parse(text) == nil, text)
}
print("PASS: actual permalink parser, post/comment/context, host and path rejection")
'''
with tempfile.TemporaryDirectory(prefix='apollo-routes-') as directory:
    swift = pathlib.Path(directory) / 'main.swift'
    swift.write_text('import Foundation\n' + parser + tests)
    executable = pathlib.Path(directory) / 'tests'
    subprocess.run(['xcrun', 'swiftc', str(swift), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
