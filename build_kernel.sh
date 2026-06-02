#!/bin/bash
# i used this script to lighter the kernel
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$PROJECT_DIR/boot"

KERNEL_DIR=$(find "$PROJECT_DIR" -maxdepth 3 -type d -name "linux-*" | head -n 1)

if [ -z "$KERNEL_DIR" ]; then
    echo "[ERROR] Could not find Linux kernel source directory (e.g., linux-7.0.10) inside the project!"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
cd "$KERNEL_DIR"

echo "=========================================="
echo "      Configuring Minimal Linux Kernel    "
echo "=========================================="

make allnoconfig

CONFIG_OPTS=(
    "CONFIG_64BIT=y"
    "CONFIG_X86_64=y"
    "CONFIG_SMP=y"
    "CONFIG_PRINTK=y"
    "CONFIG_TTY=y"
    "CONFIG_BINFMT_ELF=y"
    "CONFIG_BINFMT_SCRIPT=y"
    "CONFIG_PCI=y"
    "CONFIG_NET=y"
    "CONFIG_SERIAL_8250=y"
    "CONFIG_SERIAL_8250_CONSOLE=y"
    "CONFIG_BLK_DEV=y"
    "CONFIG_BLK_DEV_SD=y"
    "CONFIG_BLK_DEV_SR=y"
    "CONFIG_BLK_DEV_LOOP=y"
    "CONFIG_ATA=y"
    "CONFIG_SATA_AHCI=y"
    "CONFIG_ATA_PIIX=y"
    "CONFIG_EXT4_FS=y"
    "CONFIG_ISO9660_FS=y"
    "CONFIG_CDROM=y"
    "CONFIG_BLK_DEV_INITRD=y"
    "CONFIG_DEVTMPFS=y"
    "CONFIG_DEVTMPFS_MOUNT=y"
    "CONFIG_OVERLAY_FS=y"
    "CONFIG_VIRTIO_MENU=y"
    "CONFIG_VIRTIO_PCI=y"
    "CONFIG_VIRTIO_BLK=y"
    "CONFIG_NETDEVICES=y"
    "CONFIG_VIRTIO_NET=y"
    "CONFIG_VGA_CONSOLE=y"
    "CONFIG_DUMMY_CONSOLE=y"
    "CONFIG_EARLY_PRINTK=y"
    "CONFIG_IA32_EMULATION=y"
    "CONFIG_TMPFS=y"
    "CONFIG_SHMEM=y"
)

echo "[INFO] Enabling mandatory kernel options..."
for opt in "${CONFIG_OPTS[@]}"; do
    ./scripts/config --enable "${opt%%=*}"
done

make olddefconfig

echo "=========================================="
echo "      Compiling Kernel (using $(nproc) cores) "
echo "=========================================="
make -j$(nproc) bzImage

echo "[INFO] Copying bzImage to build directory..."

# save the original "bzImage" name just for fun
cp arch/x86/boot/bzImage "$OUTPUT_DIR/bzImage"

echo "[SUCCESS] Kernel build complete!"
echo "Binary located at: $OUTPUT_DIR/bzImage"