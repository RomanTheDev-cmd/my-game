"""Audit unencrypted Godot 4.6 PCK v3 contents without running external scripts."""
import pathlib
import struct
import sys
import zipfile

path = pathlib.Path(sys.argv[1])
if path.suffix == ".zip":
    with zipfile.ZipFile(path) as archive:
        packs = [n for n in archive.namelist() if n.endswith(".pck")]
        assert len(packs) == 1
        data = archive.read(packs[0])
else:
    data = path.read_bytes()
magic, version = struct.unpack_from("<II", data)
assert (magic, version) == (0x43504447, 3), "Unsupported PCK format"
offset = struct.unpack_from("<Q", data, 32)[0]
count = struct.unpack_from("<I", data, offset)[0]
assert 0 < count < 10000
cursor = offset + 4
names = set()
for _ in range(count):
    length = struct.unpack_from("<I", data, cursor)[0]
    cursor += 4
    name = data[cursor:cursor + length].rstrip(b"\0").decode("utf-8").removeprefix("res://")
    names.add(name)
    cursor += length + 36
assert "assets/fonts/LICENSE.txt" in names, "Missing font license"
assert "data/localization/strings.ru.translation" in names, "Missing Russian translation"
assert not any(n.startswith(("data/narrative/", "docs/", "tests/", "tools/", "build/")) for n in names), "Development-only content leaked into game pack"
print(f"Pack contents: {count} entries; translation and license present; internal materials excluded")
