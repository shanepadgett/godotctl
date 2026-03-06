#!/usr/bin/env bash

set -euo pipefail

repo="shanepadgett/godotctl"
version="latest"
install_dir="${HOME}/.local/bin"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      repo="$2"
      shift 2
      ;;
    --version)
      version="$2"
      shift 2
      ;;
    --install-dir)
      install_dir="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

resolve_latest_tag() {
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed -n '1p'
}

detect_os() {
  case "$(uname -s)" in
    Linux*)
      printf 'linux'
      ;;
    Darwin*)
      printf 'darwin'
      ;;
    MINGW*|MSYS*|CYGWIN*)
      printf 'windows'
      ;;
    *)
      echo "unsupported operating system: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)
      printf 'amd64'
      ;;
    arm64|aarch64)
      printf 'arm64'
      ;;
    *)
      echo "unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

verify_checksum() {
  local file="$1"
  local expected="$2"
  local actual

  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | sed 's/[[:space:]].*//')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | sed 's/[[:space:]].*//')"
  else
    echo "missing checksum tool (need sha256sum or shasum)" >&2
    exit 1
  fi

  if [ "$actual" != "$expected" ]; then
    echo "checksum mismatch for $(basename "$file")" >&2
    echo "expected: $expected" >&2
    echo "actual:   $actual" >&2
    exit 1
  fi
}

os_name="$(detect_os)"
arch_name="$(detect_arch)"

if [ "$version" = "latest" ]; then
  tag="$(resolve_latest_tag)"
  if [ -z "$tag" ]; then
    echo "failed to resolve latest release tag" >&2
    exit 1
  fi
else
  tag="$version"
  if [[ "$tag" != v* ]]; then
    tag="v${tag}"
  fi
fi

version_no_v="${tag#v}"
if [ "$os_name" = "windows" ]; then
  archive_ext="zip"
  binary_name="godotctl.exe"
else
  archive_ext="tar.gz"
  binary_name="godotctl"
fi

asset_name="godotctl_${version_no_v}_${os_name}_${arch_name}.${archive_ext}"
checksums_name="checksums.txt"
release_base_url="https://github.com/${repo}/releases/download/${tag}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

archive_path="${tmp_dir}/${asset_name}"
checksums_path="${tmp_dir}/${checksums_name}"
extract_dir="${tmp_dir}/extract"

mkdir -p "$extract_dir"

echo "downloading ${asset_name}"
curl -fL --retry 3 --retry-delay 1 "${release_base_url}/${asset_name}" -o "$archive_path"
curl -fL --retry 3 --retry-delay 1 "${release_base_url}/${checksums_name}" -o "$checksums_path"

expected_checksum="$(sed -n "s/^\([[:xdigit:]]\{64\}\)[[:space:]]\{1,\}${asset_name}$/\1/p" "$checksums_path" | sed -n '1p')"
if [ -z "$expected_checksum" ]; then
  echo "failed to find checksum entry for ${asset_name}" >&2
  exit 1
fi

verify_checksum "$archive_path" "$expected_checksum"

if [ "$archive_ext" = "zip" ]; then
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "$archive_path" -d "$extract_dir"
  elif command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "$archive_path" -C "$extract_dir"
  else
    echo "missing unzip utility (need unzip or bsdtar)" >&2
    exit 1
  fi
else
  tar -xzf "$archive_path" -C "$extract_dir"
fi

resolved_binary="$(find "$extract_dir" -type f \( -name "godotctl" -o -name "godotctl.exe" \) | sed -n '1p')"
if [ -z "$resolved_binary" ]; then
  echo "failed to locate extracted godotctl binary" >&2
  exit 1
fi

mkdir -p "$install_dir"
install_path="${install_dir}/${binary_name}"
cp "$resolved_binary" "$install_path"

if [ "$os_name" != "windows" ]; then
  chmod +x "$install_path"
fi

echo "installed ${binary_name} to ${install_path}"
if [[ ":$PATH:" != *":${install_dir}:"* ]]; then
  echo "${install_dir} is not in PATH for this shell"
  echo "add this line to your shell profile:"
  echo "  export PATH=\"${install_dir}:\$PATH\""
fi

"$install_path" version
