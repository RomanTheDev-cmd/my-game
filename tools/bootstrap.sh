#!/usr/bin/env bash
set -euo pipefail
version=4.6.3
cache="${XDG_CACHE_HOME:-$HOME/.cache}/airvel-toolchain"
data="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version.stable"
mkdir -p "$cache" "$data"
fetch_verified() {
  local name=$1 expected=$2
  if [[ ! -f "$cache/$name" ]]; then
    curl -fsSL --retry 2 --connect-timeout 30 --max-time 900 \
      "https://github.com/godotengine/godot/releases/download/$version-stable/$name" -o "$cache/$name.partial"
    mv "$cache/$name.partial" "$cache/$name"
  fi
  printf '%s  %s\n' "$expected" "$cache/$name" | sha512sum --check -
}
if ! command -v godot >/dev/null || [[ "$(godot --version)" != "$version.stable."* ]]; then
  engine="Godot_v$version-stable_linux.x86_64.zip"
  fetch_verified "$engine" a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c
  unzip -o -q "$cache/$engine" -d "$cache/engine"
  chmod +x "$cache/engine/Godot_v$version-stable_linux.x86_64"
  mkdir -p "$cache/bin"
  ln -sf "$cache/engine/Godot_v$version-stable_linux.x86_64" "$cache/bin/godot"
  export PATH="$cache/bin:$PATH"
fi
if [[ ! -f "$data/macos.zip" || ! -f "$data/linux_debug.x86_64" || ! -f "$data/linux_release.x86_64" ]]; then
  archive="Godot_v$version-stable_export_templates.tpz"
  fetch_verified "$archive" da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68
  python3 - "$cache/$archive" "$data" <<'PY'
import pathlib, sys, zipfile
out = pathlib.Path(sys.argv[2])
with zipfile.ZipFile(sys.argv[1]) as z:
    for name in ('macos.zip', 'linux_debug.x86_64', 'linux_release.x86_64', 'version.txt'):
        (out / name).write_bytes(z.read('templates/' + name))
        if name.startswith('linux_'):
            (out / name).chmod(0o755)
PY
fi
if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "$cache/bin" >> "$GITHUB_PATH"
fi
godot --version
