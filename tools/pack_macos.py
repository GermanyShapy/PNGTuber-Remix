#!/usr/bin/env python3
"""Pack a Godot macOS export folder into a zip that keeps UNIX modes.

Any zip written by a Windows tool (Explorer / 7-Zip / Compress-Archive) or
round-tripped through most cloud drives stores no POSIX attributes, so the
whole app unpacks as 644: `PNGTube-Remix.command` cannot run and the inner
Mach-O cannot exec either. This writes external_attr explicitly.

Usage:
    python pack_macos.py <folder-to-pack> [output.zip]

The top-level entry in the zip is the folder's own name, and the folder is
packed as-is (no extra wrapper level).
"""
import os
import stat
import sys
import zipfile

EXEC_SUFFIXES = (".command", ".sh", ".dylib", ".so")
EXEC_MARKERS = ("/Contents/MacOS/", "/Contents/Frameworks/")


def mode_for(rel: str) -> int:
    """755 for things macOS may need to exec, 644 otherwise."""
    if rel.endswith(EXEC_SUFFIXES) or any(m in "/" + rel for m in EXEC_MARKERS):
        return 0o100755
    return 0o100644


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    src = os.path.abspath(sys.argv[1]).rstrip("\\/")
    if not os.path.isdir(src):
        print(f"not a directory: {src}")
        return 2
    out = sys.argv[2] if len(sys.argv) > 2 else src + ".zip"
    root = os.path.basename(src)  # zip 内的顶层目录名

    n_exec = n_plain = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        # 目录条目先写，保证空目录也在包内
        for dirpath, dirnames, filenames in os.walk(src):
            dirnames.sort()
            rel_dir = os.path.relpath(dirpath, src).replace("\\", "/")
            arc_dir = root if rel_dir == "." else f"{root}/{rel_dir}"
            info = zipfile.ZipInfo(arc_dir + "/")
            info.create_system = 3  # UNIX
            info.external_attr = (0o040755 << 16) | 0x10  # dir + MS-DOS dir bit
            info.date_time = (1980, 1, 1, 0, 0, 0)
            zf.writestr(info, b"")

            for name in sorted(filenames):
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, src).replace("\\", "/")
                mode = mode_for(rel)
                info = zipfile.ZipInfo(f"{root}/{rel}")
                info.create_system = 3
                info.external_attr = mode << 16
                info.date_time = (1980, 1, 1, 0, 0, 0)
                info.compress_type = zipfile.ZIP_DEFLATED
                with open(full, "rb") as fh, zf.open(info, "w") as dst:
                    while True:
                        chunk = fh.read(1 << 20)
                        if not chunk:
                            break
                        dst.write(chunk)
                if mode == 0o100755:
                    n_exec += 1
                else:
                    n_plain += 1

    size = os.path.getsize(out)
    print(f"wrote {out} ({size/1e6:.1f} MB)  exec={n_exec} plain={n_plain}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
