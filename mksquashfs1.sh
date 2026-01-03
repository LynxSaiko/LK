cat > /home/lynx/live/scripts/mksquashfs.sh << 'EOF'
#!/bin/bash
# Buat filesystem.squashfs di /home/lynx/live/squashfs/

set -e

BASE_DIR="/home/lynx/live"
SQUASHFS_DIR="$BASE_DIR/squashfs"
LFS_MOUNT="/mnt/lfs"
ISO_STRUCTURE="$BASE_DIR/temp/iso-structure"

echo "=== MEMBUAT SQUASHFS ==="

# Bersihkan dan buat struktur
rm -rf "$SQUASHFS_DIR" "$ISO_STRUCTURE"
mkdir -p "$SQUASHFS_DIR" "$ISO_STRUCTURE"/{boot,live}

# Buat squashfs dari LFS
echo "Membuat filesystem.squashfs..."
echo "Ini mungkin memakan waktu beberapa menit..."

sudo mksquashfs "$LFS_MOUNT" "$SQUASHFS_DIR/filesystem.squashfs" \
  -comp xz \
  -b 1M \
  -noappend \
  -no-recovery \
  -processors $(nproc) \
  -wildcards \
  -e "$LFS_MOUNT"/proc \
  -e "$LFS_MOUNT"/sys \
  -e "$LFS_MOUNT"/dev \
  -e "$LFS_MOUNT"/tmp \
  -e "$LFS_MOUNT"/run \
  -e "$LFS_MOUNT"/mnt \
  -e "$LFS_MOUNT"/media \
  -e "$LFS_MOUNT"/boot \
  -e "$LFS_MOUNT"/home/* \
  -e "$LFS_MOUNT"/var/cache \
  -e "$LFS_MOUNT"/var/tmp \
  -e "$LFS_MOUNT"/var/log \
  -e "$LFS_MOUNT"/usr/share/doc \
  -e "$LFS_MOUNT"/usr/share/man \
  -e "$LFS_MOUNT"/usr/src \
  -e "$LFS_MOUNT"/usr/share/info \
  -e "$LFS_MOUNT"/usr/lib/python3.10

# Copy ke struktur ISO
cp "$SQUASHFS_DIR/filesystem.squashfs" "$ISO_STRUCTURE/live/"

echo "✓ Squashfs selesai: $SQUASHFS_DIR/filesystem.squashfs"
echo "  Size: $(du -h "$SQUASHFS_DIR/filesystem.squashfs" | cut -f1)"
EOF

chmod +x /home/lynx/live/scripts/mksquashfs.sh
