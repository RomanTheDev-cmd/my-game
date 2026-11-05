"""Verify archive integrity, bundled game data, and Apple Silicon/Intel binaries."""
import pathlib
import struct
import sys
import zipfile

archive = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None, "ZIP integrity failure"
    executables = [n for n in bundle.namelist() if "/Contents/MacOS/" in n and not n.endswith("/")]
    assert len(executables) == 1, "Expected one app executable"
    binary = bundle.read(executables[0])
    magic, count = struct.unpack_from(">II", binary)
    assert magic == 0xCAFEBABE, "Expected universal Mach-O"
    architectures = {struct.unpack_from(">I", binary, 8 + i * 20)[0] for i in range(count)}
    assert {0x01000007, 0x0100000C} <= architectures, "Missing Intel or Apple Silicon"
    assert any(n.endswith(".pck") for n in bundle.namelist()), "Missing game data"
print("macOS archive: integrity, game data, Intel and Apple Silicon OK")
