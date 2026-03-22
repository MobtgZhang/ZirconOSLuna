#!/usr/bin/env bash
# 从网络拉取 Luna 主题占位/参考资源（壁纸等）。
# Bliss 图片来自 Wikimedia / Wikipedia（版权属微软，维基上为合理使用缩略图；本地开发可替换为自有素材）。

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="${ROOT}/src/desktop/luna/resources"
WALL="${RES}/wallpapers"

mkdir -p "${WALL}"

fetch_bliss() {
  local url="https://upload.wikimedia.org/wikipedia/en/2/27/Bliss_%28Windows_XP%29.png"
  echo "Fetching Bliss wallpaper..."
  if curl -fsSL -o "${WALL}/bliss_default.png" "$url"; then
    echo "  -> ${WALL}/bliss_default.png ($(wc -c < "${WALL}/bliss_default.png") bytes)"
    return 0
  fi
  return 1
}

if fetch_bliss; then
  :
else
  echo "Bliss download failed; keeping existing file if any."
  exit 1
fi

echo "Done."
