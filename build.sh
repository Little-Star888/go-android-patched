#!/bin/bash
# 构建 play-store 补丁版 Go 工具链（目标: android/arm64, 适配 DSH 环境）
# 产物: output/go-android-arm64-patched.tar.gz
set -euo pipefail

SRC_VER=1.26.4              # 与 patches/ 对应的源码版本（补丁干跑已验证）
BOOT_VER=1.27.1             # 仅作 CI 上的 bootstrap，不进产物
PREFIX_FINAL="${PREFIX_FINAL:-/data/data/com.dsharnessmobile.shell/files/usr/lib/go}"
MIRROR="${GOMIRROR:-https://mirrors.aliyun.com/golang}"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$REPO_ROOT/work"
OUT="$REPO_ROOT/output"

mkdir -p "$WORK" "$OUT"
cd "$WORK"

# ---- 1. bootstrap Go（仅宿主自举用）----
if [ -n "${GOROOT_BOOTSTRAP:-}" ]; then
  echo "bootstrap: 使用外部 GOROOT_BOOTSTRAP=$GOROOT_BOOTSTRAP"
elif command -v go >/dev/null 2>&1 && go version >/dev/null 2>&1; then
  export GOROOT_BOOTSTRAP="$(go env GOROOT)"
  echo "bootstrap: 使用宿主 $(go version)"
else
  case "$(uname -m)" in
    x86_64) HA=amd64 ;;
    aarch64|arm64) HA=arm64 ;;
    *) echo "未知宿主架构 $(uname -m)"; exit 1 ;;
  esac
  echo "bootstrap: 下载 go${BOOT_VER}.linux-${HA}"
  curl -sLO "$MIRROR/go${BOOT_VER}.linux-${HA}.tar.gz"
  rm -rf bootstrap-go && tar xzf "go${BOOT_VER}.linux-${HA}.tar.gz" && mv go bootstrap-go
  export GOROOT_BOOTSTRAP="$PWD/bootstrap-go"
fi
"$GOROOT_BOOTSTRAP/bin/go" version

# ---- 2. Go 源码 ----
echo "source: go${SRC_VER}"
curl -sLO "$MIRROR/go${SRC_VER}.src.tar.gz"
rm -rf go-src && mkdir go-src
tar xzf "go${SRC_VER}.src.tar.gz" -C go-src --strip-components=1
cd go-src

# ---- 3. 应用 play-store fork 补丁（@TERMUX_PREFIX@ 适配为 DSH 前缀）----
DSH_USR="${PREFIX_FINAL%/lib/go}"
for p in "$REPO_ROOT"/patches/*.patch; do
  echo "patch: $(basename "$p")"
  sed "s|@TERMUX_PREFIX@|$DSH_USR|g" "$p" | git apply --unsafe-paths --directory=. -
done

# ---- 4. 交叉构建 android/arm64 工具链 ----
cd src
export GOOS=android GOARCH=arm64
export CGO_ENABLED=0
export GOROOT_FINAL="$PREFIX_FINAL"
export GO_LDSO=/system/bin/linker64
export GO_LDFLAGS="-extldflags=-pie"
./make.bash -v

# ---- 5. 打包 ----
"$WORK/go-src/bin/go" version || true
cd "$WORK"
tar czf "$OUT/go-android-arm64-patched.tar.gz" -C go-src .
ls -la "$OUT"
echo "DONE: $OUT/go-android-arm64-patched.tar.gz"
