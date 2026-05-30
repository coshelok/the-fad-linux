#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
OUTPUT_FILE="$PROJECT_DIR/boot/init.cpio.gz"
INITRAMFS_STAGE="/tmp/fadlinux_initramfs_staging"

echo "=========================================="
echo "   Compiling C-Init & Packaging Initramfs "
echo "=========================================="

rm -rf "$INITRAMFS_STAGE"
mkdir -p "$INITRAMFS_STAGE"
mkdir -p "$PROJECT_DIR/boot"

# find Cs
if [ -f "$PROJECT_DIR/init_src/init_initramfs.c" ]; then
    INIT_SOURCE="$PROJECT_DIR/init_src/init_initramfs.c"
elif [ -f "$PROJECT_DIR/init_src/init.c" ]; then
    INIT_SOURCE="$PROJECT_DIR/init_src/init.c"
else
    echo "[ERROR] Could not find any C init source file in init_src/!"
    exit 1
fi

echo "[INFO] Using source file: $INIT_SOURCE"
echo "[INFO] Compiling static init binary..."

gcc -static -o "$INITRAMFS_STAGE/init" "$INIT_SOURCE" -Os -Wall # so it doesn't use host's libs

echo "[INFO] Creating basic initramfs directory structure..."
mkdir -p "$INITRAMFS_STAGE/proc" "$INITRAMFS_STAGE/sys" "$INITRAMFS_STAGE/dev" \
         "$INITRAMFS_STAGE/run" "$INITRAMFS_STAGE/mnt" "$INITRAMFS_STAGE/tmp"

cd "$INITRAMFS_STAGE"
echo "[INFO] Packaging files into init.cpio.gz..."
find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "$OUTPUT_FILE"
cd /

rm -rf "$INITRAMFS_STAGE" # to avoid "System is deadlocked on memory"

echo "[SUCCESS] Initramfs archive created!"
echo "Location: $OUTPUT_FILE"
ls -lh "$OUTPUT_FILE"