#!/bin/bash
# direct-iso-build.sh

echo "=== Direct ISO Build (Minimal Space) ==="

# Build ISO langsung dari source tanpa copy
cd "/home/lynx/live/temp/iso-structure"

# Pastikan ada file minimal
if [ ! -f "boot/vmlinuz" ]; then
    echo "ERROR: Kernel not found"
    exit 1
fi

# Buat ISO langsung dari sini
OUTPUT_ISO="/home/lynx/live/iso/lfs-direct.iso"

# Coba buat dengan semua file yang ada
genisoimage \
    -V "LFS_DIRECT" \
    -J \
    -r \
    -c boot.cat \
    -b isolinux/isolinux.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -o "$OUTPUT_ISO" \
    . 2>&1 | grep -v "warning"

if [ $? -eq 0 ] && [ -f "$OUTPUT_ISO" ]; then
    echo "ISO created: $OUTPUT_ISO"
    echo "Size: $(du -h "$OUTPUT_ISO" | cut -f1)"
else
    echo "Trying without boot sector..."
    genisoimage -V "LFS_BASIC" -J -r -o "$OUTPUT_ISO" .
fi
