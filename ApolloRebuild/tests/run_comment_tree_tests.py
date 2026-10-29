#!/usr/bin/env python3
"""Run the controller's actual tree helpers on macOS; no UIKit/network needed."""
import pathlib
import subprocess
import tempfile

source = (pathlib.Path(__file__).resolve().parents[1] / "Sources/CommentsViewController.swift").read_text()

def declaration(marker):
    start = source.index(marker)
    opening = source.index("{", start)
    level = 1
    end = opening + 1
    while level:
        level += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]

stubs = '''
import Foundation
class RDKThing { var fullName: String?; init(_ name: String) { fullName = name } }
class RDKComment: RDKThing {
    var parentID: String?; var depth: Int; var replies: [RDKThing]?
    init(_ name: String, _ parent: String, _ depth: Int) {
        self.parentID = parent; self.depth = depth; super.init(name)
    }
}
class RDKMoreComments: RDKThing {
    var parentID: String?; var depth: Int
    init(_ name: String, _ parent: String, _ depth: Int) {
        self.parentID = parent; self.depth = depth; super.init(name)
    }
}
struct CommentsViewController {
'''
helpers = "\n".join(declaration(marker) for marker in [
    "enum Row {", "static func flatten(", "static func visibleRows(", "static func rowsFromMoreChildren("
])
tests = '''
}
typealias C = CommentsViewController
func names(_ rows: [C.Row]) -> [String] {
    rows.map { switch $0 { case .comment(let c, _): return c.fullName!
                          case .more(let m, _): return m.fullName! } }
}
let a = RDKComment("a", "post", 0)
let b = RDKComment("b", "a", 1)
let c = RDKComment("c", "post", 0)
let moreA = RDKMoreComments("more-a", "a", 1)
let moreB = RDKMoreComments("more-b", "b", 2)
let rootMore = RDKMoreComments("root-more", "post", 0)
b.replies = [moreB]; a.replies = [b, moreA]
let tree = C.flatten([a, c, rootMore], depth: 0)
assert(names(tree) == ["a", "b", "more-b", "more-a", "c", "root-more"])
let (collapsedA, countsA) = C.visibleRows(in: tree, collapsed: ["a"])
assert(names(collapsedA) == ["a", "c", "root-more"])
assert(countsA["a"] == 1)
let (collapsedB, _) = C.visibleRows(in: tree, collapsed: ["b"])
assert(names(collapsedB) == ["a", "b", "more-a", "c", "root-more"])
assert(names(C.visibleRows(in: tree, collapsed: []).0) == names(tree))
// API order isn't necessarily depth-first. Children must follow their parent.
let d = RDKComment("d", "a", 1)
let e = RDKComment("e", "d", 2)
let f = RDKComment("f", "a", 1)
let moreD = RDKMoreComments("more-d", "d", 2)
let expanded = C.rowsFromMoreChildren([e, d, f, moreD], in: tree)
assert(names(expanded) == ["d", "e", "more-d", "f"])
if case .more(_, let depth) = expanded[2] { assert(depth == 1) } else { fatalError() }
// A response arriving after collapse must remain hidden in the full tree.
let after = Array(tree.prefix(3)) + expanded + Array(tree.suffix(2))
assert(names(C.visibleRows(in: after, collapsed: ["a"]).0) == ["a", "c", "root-more"])
// Malformed cycles terminate and preserve each object once.
let x = RDKComment("x", "y", 1), y = RDKComment("y", "x", 2)
assert(C.rowsFromMoreChildren([x, y], in: []).count == 2)
print("PASS: comment tree collapse, root/nested more rows, response ordering, collapsed expansion, cycles")
'''
with tempfile.TemporaryDirectory(prefix="apollo-comment-tree-") as work:
    swift = pathlib.Path(work) / "main.swift"
    swift.write_text(stubs + helpers + tests)
    executable = pathlib.Path(work) / "tests"
    subprocess.run(["xcrun", "swiftc", str(swift), "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
