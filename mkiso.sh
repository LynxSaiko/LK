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

# Pastikan struktur ada dengan permission yang benar
mkdir -p "$ISO_DIR" "$ISO_STRUCTURE"/{boot,grub,live}

# Pastikan kita punya write permission
if [ ! -w "$ISO_DIR" ]; then
    echo "ERROR: Tidak punya write permission ke $ISO_DIR"
    echo "Coba: sudo chown -R $USER:$USER $BASE_DIR"
    exit 1
fi

# Copy initrd dan kernel
echo "1. Menyalin boot files..."
if [ -f "$BASE_DIR/initrd/initrd.img" ]; then
    cp -v "$BASE_DIR/initrd/initrd.img" "$ISO_STRUCTURE/boot/"
else
    echo "ERROR: initrd.img tidak ditemukan di $BASE_DIR/initrd/"
    echo "Jalankan mkinitrd.sh terlebih dahulu"
    exit 1
fi

# Cari kernel di LFS
echo "Mencari kernel..."
KERNEL=$(sudo find "$LFS_MOUNT/boot" -name "vmlinuz*" -type f 2>/dev/null | head -1)
if [ -f "$KERNEL" ]; then
    sudo cp -v "$KERNEL" "$ISO_STRUCTURE/boot/vmlinuz"
    echo "✓ Kernel: $(basename "$KERNEL")"
else
    echo "ERROR: Kernel tidak ditemukan di $LFS_MOUNT/boot/"
    echo "File yang ada:"
    sudo ls -la "$LFS_MOUNT/boot/" 2>/dev/null || echo "Tidak bisa akses $LFS_MOUNT/boot/"
    exit 1
fi

# Copy squashfs
echo "2. Menyalin squashfs..."
if [ -f "$BASE_DIR/squashfs/filesystem.squashfs" ]; then
    cp -v "$BASE_DIR/squashfs/filesystem.squashfs" "$ISO_STRUCTURE/live/"
    echo "✓ Squashfs: $(du -h "$ISO_STRUCTURE/live/filesystem.squashfs" | cut -f1)"
else
    echo "ERROR: filesystem.squashfs tidak ditemukan di $BASE_DIR/squashfs/"
    echo "Jalankan mksquashfs.sh terlebih dahulu"
    exit 1
fi

# Verifikasi file sebelum buat ISO
echo ""
echo "=== VERIFIKASI FILE ==="
echo "Struktur di $ISO_STRUCTURE:"
tree "$ISO_STRUCTURE" 2>/dev/null || find "$ISO_STRUCTURE" -type f | xargs ls -lh

# Buat GRUB config
echo ""
echo "3. Membuat konfigurasi GRUB..."
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

# Buat file .disk untuk identifikasi
echo "4. Membuat identifikasi disk..."
cat > "$ISO_STRUCTURE/.disk/info" << "DISKINFO"
LFS 11.2 Live System
Build date: $(date)
DISKINFO

mkdir -p "$ISO_STRUCTURE/.disk"
echo "LFS 11.2 Live" > "$ISO_STRUCTURE/.disk/info"

# Buat ISO dengan xorriso
echo ""
echo "5. Membuat ISO image..."
echo "Menggunakan xorriso dari: $(which xorriso)"

# Cd ke parent directory dari ISO_STRUCTURE
cd "$(dirname "$ISO_STRUCTURE")"

# Gunakan path relatif untuk menghindari masalah
ISO_BASENAME="$(basename "$ISO_STRUCTURE")"
FULL_ISO_PATH="$ISO_DIR/$ISO_NAME"

echo "Working directory: $(pwd)"
echo "ISO Structure: $ISO_BASENAME"
echo "Output ISO: $FULL_ISO_PATH"

# Hapus ISO lama jika ada
rm -f "$FULL_ISO_PATH"

# Buat ISO
xorriso -as mkisofs \
  -volid "LFS_11_2_LIVE" \
  -full-iso9660-filenames \
  -rational-rock \
  -joliet \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-boot \
  -output "$FULL_ISO_PATH" \
  "$ISO_BASENAME"

# Cek apakah ISO berhasil dibuat
if [ ! -f "$FULL_ISO_PATH" ]; then
    echo "ERROR: Gagal membuat ISO!"
    echo "Coba command manual:"
    echo "cd $(dirname "$ISO_STRUCTURE") && xorriso -as mkisofs -volid 'LFS_LIVE' -output '$FULL_ISO_PATH' '$ISO_BASENAME'"
    exit 1
fi

echo "✓ ISO selesai: $FULL_ISO_PATH"
echo "  Size: $(du -h "$FULL_ISO_PATH" | cut -f1)"

# Coba buat hybrid ISO
if command -v isohybrid &> /dev/null; then
    echo "6. Membuat hybrid ISO (USB bootable)..."
    isohybrid "$FULL_ISO_PATH" 2>/dev/null || echo "  Warning: isohybrid gagal, ISO tetap bootable"
fi

# Buat checksums
echo ""
echo "7. Membuat checksums..."
cd "$ISO_DIR"
md5sum "$ISO_NAME" > "$ISO_NAME.md5"
sha256sum "$ISO_NAME" > "$ISO_NAME.sha256"

echo ""
echo "========================================"
echo "✓ ISO BERHASIL DIBUAT!"
echo "Lokasi: $FULL_ISO_PATH"
echo "Size:   $(du -h "$FULL_ISO_PATH" | cut -f1)"
echo "MD5:    $(cat "$ISO_NAME.md5" | cut -d' ' -f1)"
echo ""
echo "Untuk test:"
echo "  qemu-system-x86_64 -cdrom '$FULL_ISO_PATH' -m 2G"
echo "========================================"
EOF

chmod +x /home/lynx/live/scripts/mkiso.sh
