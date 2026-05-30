#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
OUTPUT="$PROJECT_DIR/rootfs.ext4"
ROOTFS_SIZE_MB=64
STAGING="/tmp/fadlinux_rootfs_staging"

echo "=========================================="
echo "      Creating FAD Linux rootfs.ext4      "
echo "=========================================="

rm -rf "$STAGING"
mkdir -p "$STAGING"

echo "[INFO] Creating standard directory tree..."
for d in proc sys dev run mnt tmp var root home bin sbin etc; do
    mkdir -p "$STAGING/$d"
done

if [ -d "$PROJECT_DIR/rust_utils" ]; then
    echo "[INFO] Copying compiled utilities from rust_utils..."
    # copying the binaries you have
    find "$PROJECT_DIR/rust_utils" -type f -not -path '*/.*' -exec cp {} "$STAGING/bin/" \; 2>/dev/null || true
fi

if [ -d "$PROJECT_DIR/etc" ]; then
    echo "[INFO] Copying configuration files to /etc..."
    cp -a "$PROJECT_DIR/etc"/* "$STAGING/etc/" 2>/dev/null || true
fi

echo "[INFO] Creating essential device nodes..."
mknod "$STAGING/dev/console" c 5 1 2>/dev/null || true
mknod "$STAGING/dev/null" c 1 3 2>/dev/null || true
mknod "$STAGING/dev/tty" c 5 0 2>/dev/null || true

echo "[INFO] Allocating raw image space ($ROOTFS_SIZE_MB MB)..."
dd if=/dev/zero of="$OUTPUT" bs=1M count=$ROOTFS_SIZE_MB 2>/dev/null

echo "[INFO] Formatting image as ext4..."
mkfs.ext4 -F -L "fadroot" -d "$STAGING" "$OUTPUT" 2>&1 | tail -n 3

rm -rf "$STAGING"

echo "[SUCCESS] rootfs.ext4 successfully created!"
echo "Location: $OUTPUT"
ls -lh "$OUTPUT"

