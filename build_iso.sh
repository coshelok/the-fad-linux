#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_ISO="$PROJECT_DIR/../fadlinux-v0.2.iso"

echo "=========================================="
echo "      Building FAD Linux Bootable ISO     "
echo "=========================================="

echo "[INFO] Injecting standard Linux utilities (BusyBox)..."
mkdir -p "$PROJECT_DIR/rootfs/bin"

if [ ! -f "$PROJECT_DIR/busybox" ]; then
    echo "[INFO] Downloading static BusyBox..."
    wget -q -O "$PROJECT_DIR/busybox" https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
    chmod +x "$PROJECT_DIR/busybox"
fi

cp "$PROJECT_DIR/busybox" "$PROJECT_DIR/rootfs/bin/busybox"

echo "[INFO] Creating symlinks for commands..."
cd "$PROJECT_DIR/rootfs/bin"
./busybox --list | while read -r cmd; do
    ln -sf busybox "$cmd"
done
ln -sf busybox bash
cd "$PROJECT_DIR"

echo "[INFO] Preparing fadfetch..."
if [ -f "$PROJECT_DIR/fad_utils/fadfetch" ]; then
    cp "$PROJECT_DIR/fad_utils/fadfetch" "$PROJECT_DIR/rootfs/bin/fadfetch"
    chmod +x "$PROJECT_DIR/rootfs/bin/fadfetch"
    echo "[SUCCESS] fadfetch added to rootfs/bin/fadfetch"
else
    echo "[WARNING] fadfetch.sh not found, skipping..."
fi

echo "[INFO] Rebuilding rootfs.ext4 image (256M, label: fadroot)..."
rm -f "$PROJECT_DIR/rootfs.ext4"
mkfs.ext4 -L fadroot -d "$PROJECT_DIR/rootfs" "$PROJECT_DIR/rootfs.ext4" 256M

echo "[INFO] Compiling custom init.c and updating initramfs..."
gcc -static "$PROJECT_DIR/init_src/init.c" -o "$PROJECT_DIR/init"

mkdir -p "$PROJECT_DIR/boot"
(cd "$PROJECT_DIR" && echo "init" | cpio -o -H newc) | gzip -9 > "$PROJECT_DIR/boot/init.cpio.gz"
rm -f "$PROJECT_DIR/init"


if [ ! -f "$PROJECT_DIR/boot/bzImage" ]; then
    echo "[ERROR] Missing bzImage!" && exit 1
fi
if [ ! -f "$PROJECT_DIR/boot/init.cpio.gz" ]; then
    echo "[ERROR] Missing initramfs!" && exit 1
fi
if [ ! -f "$PROJECT_DIR/boot/grub/grub.cfg" ]; then
    echo "[ERROR] Missing grub.cfg!" && exit 1
fi


echo "[INFO] Creating clean ISO staging directory..."
STAGING_DIR="$PROJECT_DIR/iso_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/boot/grub"

cp "$PROJECT_DIR/boot/bzImage" "$STAGING_DIR/boot/"
cp "$PROJECT_DIR/boot/init.cpio.gz" "$STAGING_DIR/boot/"
cp "$PROJECT_DIR/boot/grub/grub.cfg" "$STAGING_DIR/boot/grub/"
cp "$PROJECT_DIR/rootfs.ext4" "$STAGING_DIR/"

echo "[INFO] Packaging files into bootable image from staging..."
GRUB_THEME="" grub-mkrescue -o "$OUTPUT_ISO" "$STAGING_DIR"

rm -rf "$STAGING_DIR"

echo "=========================================="
echo "[SUCCESS] ISO successfully created!"
echo "Location: $OUTPUT_ISO"
ls -lh "$OUTPUT_ISO"
echo "=========================================="