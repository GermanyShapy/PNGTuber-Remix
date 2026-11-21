#!/usr/bin/env python3
"""Pack a Godot Windows export folder into a zip with one top-level folder.

The export writes loose files next to the exe, so a plain "compress this
folder" produces an extra wrapper level or a flat mess of 12 files at the
archive root. This always emits `<folder-name>/` as the single top-level
entry, in sorted order, so two builds of the same tree compare byte for byte.

Usage:
    python pack_windows.py <folder-to-pack> [output.zip]
"""
import os
import sys
import zipfile


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    src = os.path.abspath(sys.argv[1]).rstrip("\\/")
    if not os.path.isdir(src):
        print(f"not a directory: {src}")
        return 2
    out = sys.argv[2] if len(sys.argv) > 2 else src + ".zip"
    if os.path.abspath(out).startswith(src + os.sep):
        print("refusing to write the zip inside the folder it packs")
        return 2
    root = os.path.basename(src)

    names = sorted(os.listdir(src))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        info = zipfile.ZipInfo(root + "/")
        info.create_system = 3  # UNIX, so viewers show a directory
        info.external_attr = (0o040755 << 16) | 0x10
        zf.writestr(info, b"")

        for name in names:
            full = os.path.join(src, name)
            if not os.path.isfile(full):
                print(f"skip non-file entry: {name}")
                continue
            entry = zipfile.ZipInfo(f"{root}/{name}")
            entry.create_system = 3
            entry.external_attr = 0o100755 << 16  # Windows ignores modes
            entry.compress_type = zipfile.ZIP_DEFLATED
            with open(full, "rb") as fh, zf.open(entry, "w") as dst:
                while True:
                    chunk = fh.read(1 << 20)
                    if not chunk:
                        break
                    dst.write(chunk)

    print(f"wrote {out} ({os.path.getsize(out)} B)  files={len(names)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
