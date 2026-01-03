cat > /home/lynx/live/scripts/mkiso.sh << 'EOF'
#!/bin/bash
# Buat ISO di /home/lynx/live/iso/

set -e

BASE_DIR="/home/lynx/live"
ISO_DIR="$BASE_DIR/iso"
ISO_NAME="lfs-11.2-live.iso"
LFS_MOUNT="/mnt/lfs"
ISO_STRUCTURE="$BASE_DIR/temp/iso-structure"

echo "=== MEMBUAT ISO ==="

# Pastikan struktur ada
mkdir -p "$ISO_DIR" "$ISO_STRUCTURE"/{boot,grub,live}

# Copy initrd dan kernel
echo "1. Menyalin boot files..."
if [ -f "$BASE_DIR/initrd/initrd.img" ]; then
    cp "$BASE_DIR/initrd/initrd.img" "$ISO_STRUCTURE/boot/"
else
    echo "ERROR: initrd.img tidak ditemukan!"
    exit 1
fi

# Cari kernel di LFS
KERNEL=$(find "$LFS_MOUNT/boot" -name "vmlinuz*" -type f | head -1)
if [ -f "$KERNEL" ]; then
    cp "$KERNEL" "$ISO_STRUCTURE/boot/vmlinuz"
    echo "✓ Kernel: $(basename "$KERNEL")"
else
    echo "ERROR: Kernel tidak ditemukan di $LFS_MOUNT/boot/"
    exit 1
fi

# Copy squashfs jika belum ada
if [ ! -f "$ISO_STRUCTURE/live/filesystem.squashfs" ] && \
   [ -f "$BASE_DIR/squashfs/filesystem.squashfs" ]; then
    cp "$BASE_DIR/squashfs/filesystem.squashfs" "$ISO_STRUCTURE/live/"
fi

# Buat GRUB config
echo "2. Membuat konfigurasi GRUB..."
cat > "$ISO_STRUCTURE/boot/grub/grub.cfg" << "GRUBCFG"
set timeout=10
set default=0

menuentry "LFS 11.2 Live System" {
    linux /boot/vmlinuz boot=live components quiet
    initrd /boot/initrd.img
}

menuentry "LFS 11.2 (Text Mode)" {
    linux /boot/vmlinuz boot=live components 3
    initrd /boot/initrd.img
}

menuentry "LFS 11.2 (Debug Mode)" {
    linux /boot/vmlinuz boot=live components debug
    initrd /boot/initrd.img
}

menuentry "LFS 11.2 (Persistent Storage)" {
    linux /boot/vmlinuz boot=live persistent
    initrd /boot/initrd.img
}
GRUBCFG

# Buat ISO dengan xorriso
echo "3. Membuat ISO image..."
cd "$ISO_STRUCTURE"

xorriso -as mkisofs \
  -volid "LFS_11.2_LIVE" \
  -full-iso9660-filenames \
  -rational-rock \
  -joliet \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-boot \
  -output "$ISO_DIR/$ISO_NAME" \
  .

# Coba buat hybrid ISO
if command -v isohybrid &> /dev/null; then
    echo "4. Membuat hybrid ISO (USB bootable)..."
    isohybrid "$ISO_DIR/$ISO_NAME" 2>/dev/null || true
fi

echo "✓ ISO selesai: $ISO_DIR/$ISO_NAME"
echo "  Size: $(du -h "$ISO_DIR/$ISO_NAME" | cut -f1)"

# Buat checksums
echo "5. Membuat checksums..."
cd "$ISO_DIR"
md5sum "$ISO_NAME" > "$ISO_NAME.md5"
sha256sum "$ISO_NAME" > "$ISO_NAME.sha256"

echo "========================================"
echo "ISO berhasil dibuat!"
echo "Lokasi: $ISO_DIR/$ISO_NAME"
echo "MD5:    $(cat "$ISO_NAME.md5" | cut -d' ' -f1)"
echo "========================================"
EOF

chmod +x /home/lynx/live/scripts/mkiso.sh
