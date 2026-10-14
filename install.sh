#!/usr/bin/env bash
set -euo pipefail
case "$(uname -m)" in x86_64) ;; *) echo "只支持 x86_64；当前架构：$(uname -m)" >&2; exit 1 ;; esac
SOURCE_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
DEST="$HOME/.vscode-server/centos7-glibc"
OVERRIDE="$(printenv VSCODE_GLIBC_INSTALL_DIR || true)"
if [ -n "$OVERRIDE" ]; then DEST="$OVERRIDE"; fi
BASHRC="$HOME/.bashrc"
ENV_FILE="$DEST/centos7-glibc-env.sh"
PATCHELF="$DEST/patchelf/bin/patchelf"
LINKER="$DEST/sysroot/lib/ld-linux-x86-64.so.2"
LIBPATH="$DEST/sysroot/lib"
if [ -e "$DEST" ]; then
  if [ ! -x "$PATCHELF" ] || [ ! -e "$LINKER" ]; then
    echo "目标目录已存在但不是完整安装，停止以免覆盖：$DEST" >&2
    exit 2
  fi
  echo "运行库已存在：$DEST"
else
  mkdir -p "$(dirname -- "$DEST")"
  cp -a "$SOURCE_DIR/payload" "$DEST"
  echo "运行库已安装：$DEST"
fi
if [ ! -f "$ENV_FILE" ]; then
  cat > "$ENV_FILE" <<ENV
export VSCODE_SERVER_CUSTOM_GLIBC_LINKER="$LINKER"
export VSCODE_SERVER_CUSTOM_GLIBC_PATH="$LIBPATH"
export VSCODE_SERVER_PATCHELF_PATH="$PATCHELF"
ENV
fi
# Repoint already-installed Remote-SSH Node binaries so they no longer depend
# on a previous sysroot. Patch a temporary copy, test it, then atomically replace.
PATCHED=0
for SERVER_NODE in "$HOME/.vscode-server"/cli/servers/*/server/node "$HOME/.vscode-server"/bin/*/node; do
  [ -f "$SERVER_NODE" ] || continue
  CURRENT_LINKER="$("$PATCHELF" --print-interpreter "$SERVER_NODE" 2>/dev/null || true)"
  CURRENT_LIBPATH="$("$PATCHELF" --print-rpath "$SERVER_NODE" 2>/dev/null || true)"
  if [ "$CURRENT_LINKER" = "$LINKER" ] && [ "$CURRENT_LIBPATH" = "$LIBPATH" ]; then
    continue
  fi
  TEMP_NODE="$SERVER_NODE.cent7glibc.$$"
  cp -p "$SERVER_NODE" "$TEMP_NODE"
  if ! "$PATCHELF" --set-rpath "$LIBPATH" "$TEMP_NODE" ||
     ! "$PATCHELF" --set-interpreter "$LINKER" "$TEMP_NODE" ||
     ! "$TEMP_NODE" --version >/dev/null 2>&1; then
    rm -f "$TEMP_NODE"
    echo "无法安全迁移现有 Node：$SERVER_NODE；原文件未更改。" >&2
    exit 3
  fi
  mv -f "$TEMP_NODE" "$SERVER_NODE"
  PATCHED=$((PATCHED + 1))
  echo "已迁移现有 VS Code Node：$SERVER_NODE"
done
if [ "$PATCHED" -eq 0 ]; then
  echo "没有需要迁移的现有 VS Code Node。"
fi
if [ -f "$BASHRC" ] && grep -Eq 'VSCODE_SERVER_(CUSTOM_GLIBC|PATCHELF)' "$BASHRC"; then
  if grep -Fq "$ENV_FILE" "$BASHRC"; then
    echo ".bashrc 已加载 CentOS 7 配置。"
  else
    echo "检测到 .bashrc 已有 VS Code 自定义运行库变量；为避免覆盖，未修改它。"
    echo "若要由此安装接管新 Server，请检查后自行加载：. \"$ENV_FILE\""
  fi
elif grep -Fq "$ENV_FILE" "$BASHRC" 2>/dev/null; then
  echo ".bashrc 已加载 CentOS 7 配置，无需重复修改。"
else
  if [ ! -e "$BASHRC" ]; then
    : > "$BASHRC"
  else
    BACKUP="$BASHRC.bak-centos7-glibc-$(date +%Y%m%d%H%M%S)-$$"
    cp -p "$BASHRC" "$BACKUP"
    echo "原 .bashrc 备份在：$BACKUP"
  fi
  printf '\n[ -r "%s" ] && . "%s"\n' "$ENV_FILE" "$ENV_FILE" >> "$BASHRC"
  echo "已在 .bashrc 添加一行加载配置。"
fi
echo "完成。重新连接 Remote-SSH 使配置生效。"
