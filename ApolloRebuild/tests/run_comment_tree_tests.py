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
    var parentID: String?; var depth: Int; var replies: [RDKThing]?; var body: String?; var author: String?
    init(_ name: String, _ parent: String, _ depth: Int) {
        self.parentID = parent; self.depth = depth; super.init(name)
    }
}
class RDKMoreComments: RDKThing {
    var parentID: String?; var depth: Int; var count: Int = 0; var children: [String] = []
    init(_ name: String, _ parent: String, _ depth: Int) {
        self.parentID = parent; self.depth = depth; super.init(name)
    }
}
struct CommentsViewController {
'''
helpers = "\n".join(declaration(marker) for marker in [
    "enum Row {", "static func flatten(", "static func visibleRows(", "static func rowsFromMoreChildren(",
    "static func insertingSubmittedComment(", "static func mergingParents(", "static func matchingRows(",
    "static func selectableText(forComment"
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
moreA.count = 3
let moreB = RDKMoreComments("more-b", "b", 2)
let rootMore = RDKMoreComments("root-more", "post", 0)
b.replies = [moreB]; a.replies = [b, moreA]
let tree = C.flatten([a, c, rootMore], depth: 0)
assert(names(tree) == ["a", "b", "more-b", "more-a", "c", "root-more"])
let (collapsedA, countsA) = C.visibleRows(in: tree, collapsed: ["a"])
assert(names(collapsedA) == ["a", "c", "root-more"])
// a loaded reply plus whatever the nested stub stands for
assert(countsA["a"] == 1 + moreA.count)
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
let reply = RDKComment("reply", "b", 0)
let (inserted, uncollapsed) = C.insertingSubmittedComment(reply, in: tree, postFullName: "post", collapsed: ["a", "b", "c"])
assert(names(inserted) == ["a", "b", "reply", "more-b", "more-a", "c", "root-more"])
assert(uncollapsed == ["c"])
assert(names(C.visibleRows(in: inserted, collapsed: uncollapsed).0).contains("reply"))
if case .comment(_, let depth) = inserted[2] { assert(depth == 2) } else { fatalError() }
assert(names(C.insertingSubmittedComment(reply, in: inserted, postFullName: "post", collapsed: []).0) == names(inserted))
let rootReply = RDKComment("root-reply", "post", 0)
assert(names(C.insertingSubmittedComment(rootReply, in: tree, postFullName: "post", collapsed: []).0).first == "root-reply")
let orphan = RDKComment("orphan", "absent-parent", 0)
assert(names(C.insertingSubmittedComment(orphan, in: tree, postFullName: "post", collapsed: []).0) == names(tree))
let ancestor = RDKComment("ancestor", "post", 0)
let responseA = RDKComment("a", "ancestor", 1)
a.parentID = "ancestor"; ancestor.replies = [responseA]
let merged = C.mergingParents([ancestor], into: tree)
assert(names(merged) == ["ancestor", "a", "b", "more-b", "more-a", "c", "root-more"])
if case .comment(let original, let depth) = merged[1] { assert(original === a && depth == 1) } else { fatalError() }
if case .comment(_, let depth) = merged[5] { assert(depth == 0) } else { fatalError() }
assert(names(C.mergingParents([ancestor], into: merged)) == names(merged))
assert(names(C.mergingParents([], into: tree)) == names(tree))
a.body = "Incredible COLOURS, café"; b.body = "no match here"; c.body = nil
a.author = "first_commenter"
let selectable = C.selectableText(forComment: a)
assert(selectable.hasPrefix("u/first_commenter:"))
assert(selectable.hasSuffix("Incredible COLOURS, café"))
a.author = nil
assert(C.selectableText(forComment: a) == "Incredible COLOURS, café")
a.body = nil
assert(C.selectableText(forComment: a) == "")
a.body = "Incredible COLOURS, café"; a.author = "first_commenter"
assert(C.matchingRows(in: tree, query: "colours") == [0])
assert(C.matchingRows(in: tree, query: "cafe") == [0])
assert(C.matchingRows(in: tree, query: "  ") == [])
assert(C.matchingRows(in: tree, query: "much better") == [])
print("PASS: comment tree collapse, ordering, cycles, reply insertion, ancestor merge, find matching")
'''
with tempfile.TemporaryDirectory(prefix="apollo-comment-tree-") as work:
    swift = pathlib.Path(work) / "main.swift"
    swift.write_text(stubs + helpers + tests)
    executable = pathlib.Path(work) / "tests"
    subprocess.run(["xcrun", "swiftc", str(swift), "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
