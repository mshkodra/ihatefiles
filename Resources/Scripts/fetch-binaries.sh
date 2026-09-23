#!/usr/bin/env bash
# Fetches and checksum-verifies the yt-dlp and ffmpeg binaries this app bundles.
# Idempotent: skips re-downloading a binary that's already present with a
# matching checksum. See Resources/VERSIONS.md for what's currently pinned.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$RESOURCES_DIR/bin"

YTDLP_VERSION="2026.08.19"
YTDLP_URL="https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP_VERSION}/yt-dlp_macos"
YTDLP_SHA256="0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202"

FFMPEG_VERSION="9.0"
FFMPEG_ZIP_URL="https://www.osxexperts.net/ffmpeg9arm.zip"
FFMPEG_ZIP_SHA256="d0c06c5c68ce48af3143b262f7a9118a7c9f67de1e237fcc24ffb14df9c67af9"
FFMPEG_BIN_SHA256="591260c945d0eef150e3bf82b0ef988bd36a9cecc18ff05d6679617159f0a95e"

mkdir -p "$BIN_DIR"

verify_sha256() {
  local file="$1" expected="$2"
  local actual
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "Checksum mismatch for $file" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    rm -f "$file"
    exit 1
  fi
}

fetch_ytdlp() {
  local dest="$BIN_DIR/yt-dlp"
  if [[ -f "$dest" ]] && shasum -a 256 "$dest" | awk '{print $1}' | grep -qx "$YTDLP_SHA256"; then
    echo "yt-dlp $YTDLP_VERSION already present and verified, skipping."
    return
  fi
  echo "Downloading yt-dlp $YTDLP_VERSION..."
  curl -sL --fail -o "$dest" "$YTDLP_URL"
  verify_sha256 "$dest" "$YTDLP_SHA256"
  chmod +x "$dest"
  echo "yt-dlp $YTDLP_VERSION verified and installed."
}

fetch_ffmpeg() {
  local dest="$BIN_DIR/ffmpeg"
  if [[ -f "$dest" ]] && shasum -a 256 "$dest" | awk '{print $1}' | grep -qx "$FFMPEG_BIN_SHA256"; then
    echo "ffmpeg $FFMPEG_VERSION already present and verified, skipping."
    return
  fi
  echo "Downloading ffmpeg $FFMPEG_VERSION (arm64)..."
  local tmp_zip
  tmp_zip="$(mktemp -t ffmpeg-download.XXXXXX).zip"
  curl -sL --fail -o "$tmp_zip" "$FFMPEG_ZIP_URL"
  verify_sha256 "$tmp_zip" "$FFMPEG_ZIP_SHA256"

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  unzip -o -q "$tmp_zip" -d "$tmp_dir"
  rm -f "$tmp_zip"

  cp "$tmp_dir/ffmpeg" "$dest"
  rm -rf "$tmp_dir"
  verify_sha256 "$dest" "$FFMPEG_BIN_SHA256"
  chmod +x "$dest"
  xattr -c "$dest" 2>/dev/null || true
  echo "ffmpeg $FFMPEG_VERSION verified and installed."
}

fetch_ytdlp
fetch_ffmpeg
echo "All binaries ready in $BIN_DIR"
