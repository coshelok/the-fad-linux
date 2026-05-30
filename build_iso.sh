#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_ISO="$PROJECT_DIR/../fadlinux.iso"

echo "=========================================="
echo "      Building FAD Linux Bootable ISO     "
echo "=========================================="

if [ ! -f "$PROJECT_DIR/boot/bzImage" ]; then
    echo "[ERROR] Missing $PROJECT_DIR/boot/bzImage! Build the kernel first."
    exit 1
fi

if [ ! -f "$PROJECT_DIR/boot/init.cpio.gz" ]; then
    echo "[ERROR] Missing $PROJECT_DIR/boot/init.cpio.gz! Build the initramfs first."
    exit 1
fi

if [ ! -f "$PROJECT_DIR/boot/grub/grub.cfg" ]; then
    echo "[ERROR] Missing $PROJECT_DIR/boot/grub/grub.cfg!"
    exit 1
fi

echo "[INFO] Packaging files into bootable image..."

# empty grub theme for light weight
GRUB_THEME="" grub-mkrescue -o "$OUTPUT_ISO" "$PROJECT_DIR"


echo "[SUCCESS] ISO successfully created!"
echo "Location: $OUTPUT_ISO"
ls -lh "$OUTPUT_ISO"

echo "Run it with:"
# just delete "-nographic" to run in a window (not working; idk why it's not working outside linux console =) ), kvm for super fast 1000fps bare terminal
echo "qemu-system-x86_64 -enable-kvm -m 2G -cdrom $OUTPUT_ISO -boot d -nographic" 
