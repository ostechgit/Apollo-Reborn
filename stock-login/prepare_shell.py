#!/usr/bin/env python3
"""Patch a Mach-O's LC_BUILD_VERSION platform iOS -> iOS-Simulator.

Same transformation the Reborn tweak's simulator flow applies: the arm64 code in
a decrypted device Apollo is identical to what the simulator runs, only the
platform tag blocks dyld from loading it.

Usage: prepare_shell.py <mach-o> [more...]
"""

import struct
import sys

LC_BUILD_VERSION = 0x32
PLATFORM_IOS = 2
PLATFORM_IOSSIMULATOR = 7


def patch(path):
    data = bytearray(open(path, "rb").read())
    if struct.unpack("<I", data[0:4])[0] != 0xFEEDFACF:
        return "skip (not 64-bit LE mach-o)"
    ncmds = struct.unpack("<I", data[16:20])[0]
    off = 32
    actions = []
    for _ in range(ncmds):
        cmd, size = struct.unpack("<II", data[off:off + 8])
        if cmd == LC_BUILD_VERSION:
            platform = struct.unpack("<I", data[off + 8:off + 12])[0]
            if platform == PLATFORM_IOS:
                struct.pack_into("<I", data, off + 8, PLATFORM_IOSSIMULATOR)
                actions.append("iOS->sim")
            else:
                actions.append(f"platform={platform} (left alone)")
        off += size
    open(path, "wb").write(data)
    return ", ".join(actions) or "no LC_BUILD_VERSION"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    for path in sys.argv[1:]:
        print(f"  {path.rsplit('/', 1)[-1]}: {patch(path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
