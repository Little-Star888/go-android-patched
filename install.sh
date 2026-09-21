#!/bin/bash
# 设备端安装: bash install.sh <解包出的go根目录>
set -e
SRC="${1:?usage: bash install.sh <go-root-dir>}"
[ -x "$SRC/bin/go" ] || { echo "错误: $SRC/bin/go 不存在，确认解包目录"; exit 1; }
[ -d "$PREFIX/lib/go" ] && { rm -rf "$PREFIX/lib/go.old"; mv "$PREFIX/lib/go" "$PREFIX/lib/go.old"; }
mv "$SRC" "$PREFIX/lib/go"
ln -sf "$PREFIX/lib/go/bin/go" "$PREFIX/bin/go"
ln -sf "$PREFIX/lib/go/bin/gofmt" "$PREFIX/bin/gofmt"
"$PREFIX/lib/go/bin/go" version && echo "安装完成（旧版备份于 \$PREFIX/lib/go.old）"
