#!/usr/bin/env python3
"""Fetch only the official Godot 4.5.1 Windows x86_64 release template using ZIP byte ranges.

Requires Python stdlib and curl. No global template installation is performed.
The version and exact archive size are fixed, and extracted CRC is verified.
"""
from pathlib import Path
import argparse
import json
import struct
import subprocess
import tempfile
import zipfile
import zlib

URL = "https://github.com/godotengine/godot-builds/releases/download/4.5.1-stable/Godot_v4.5.1-stable_export_templates.tpz"
ARCHIVE_SIZE = 1355592535


def fetch(start, end, destination):
    subprocess.run(["curl", "-L", "--fail", "--retry", "2", "--max-filesize", str(end-start+2), "--range", f"{start}-{end}", "--output", str(destination), URL], check=True)
    expected = end-start+1
    if destination.stat().st_size != expected:
        raise RuntimeError(f"Server did not honor range {start}-{end}; expected {expected} bytes, received {destination.stat().st_size}.")
    return destination.read_bytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="godot-windows-template-") as folder:
        scratch = Path(folder)
        tail = fetch(ARCHIVE_SIZE-65536, ARCHIVE_SIZE-1, scratch/"tail.bin")
        pos = 0
        entry = None
        while True:
            pos = tail.find(b"PK\x01\x02", pos)
            if pos < 0:
                break
            fields = struct.unpack_from("<4s6H3I5H2I", tail, pos)
            name = tail[pos+46:pos+46+fields[10]].decode()
            if name == "templates/windows_release_x86_64.exe":
                entry = {"compressed": fields[8], "size": fields[9], "offset": fields[16], "method": fields[4], "crc": fields[7]}
                break
            pos += 46+fields[10]+fields[11]+fields[12]
        if entry is None:
            raise RuntimeError("Official archive directory contains no templates/windows_release_x86_64.exe entry.")
        header = fetch(entry["offset"], entry["offset"]+29, scratch/"header.bin")
        fields = struct.unpack("<4s5H3I2H", header)
        if fields[0] != b"PK\x03\x04":
            raise RuntimeError("Invalid ZIP local header.")
        start = entry["offset"]+30+fields[9]+fields[10]
        compressed = fetch(start, start+entry["compressed"]-1, scratch/"member.bin")
        data = zlib.decompress(compressed, -15) if entry["method"] == 8 else compressed
        if len(data) != entry["size"] or zlib.crc32(data)&0xffffffff != entry["crc"]:
            raise RuntimeError("Official Windows x86_64 release template CRC/size validation failed.")
        temp = args.output.with_suffix(".part")
        temp.write_bytes(data)
        if data[:2] != b"MZ":
            raise RuntimeError("Official Windows template is not a PE executable.")
        pe_offset = struct.unpack_from("<I", data, 0x3c)[0]
        if data[pe_offset:pe_offset+4] != b"PE\x00\x00" or struct.unpack_from("<H", data, pe_offset+4)[0] != 0x8664:
            raise RuntimeError("Expected an x86_64 Windows PE template.")
        temp.replace(args.output)
        args.output.with_suffix(".source.json").write_text(json.dumps({"godot_version": "4.5.1-stable", "source": URL, "member": "templates/windows_release_x86_64.exe", "crc32": f'{entry["crc"]:08x}', "size": len(data)}, indent=2)+"\n")
        print(f"Verified official template: {args.output} ({len(data):,} bytes)")


if __name__ == "__main__":
    main()
