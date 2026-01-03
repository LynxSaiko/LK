cat > /home/lynx/live/scripts/mount-lfs.sh << 'EOF'
#!/bin/bash
# Mount LFS partition

LFS_MOUNT="/mnt/lfs"
# GANTI DENGAN PARTISI LFS ANDA!
LFS_PARTITION="/dev/sda2"

echo "=== MOUNT LFS PARTITION ==="

# Cek apakah sudah root
if [ "$EUID" -ne 0 ]; then
    echo "Jalankan dengan sudo"
    exit 1
fi

# Unmount jika sudah mounted
umount -R "$LFS_MOUNT" 2>/dev/null || true

# Buat mount point
mkdir -p "$LFS_MOUNT"

# Mount partition
if mount "$LFS_PARTITION" "$LFS_MOUNT"; then
    echo "✓ Partition mounted: $LFS_PARTITION → $LFS_MOUNT"
else
    echo "✗ Gagal mount $LFS_PARTITION"
    echo "Cek partisi dengan: lsblk"
    exit 1
fi

# Mount virtual filesystems
mount --bind /dev "$LFS_MOUNT/dev"
mount --bind /dev/pts "$LFS_MOUNT/dev/pts"
mount --bind /proc "$LFS_MOUNT/proc"
mount --bind /sys "$LFS_MOUNT/sys"
mount --bind /run "$LFS_MOUNT/run"


echo "✓ Virtual filesystems mounted"
echo "✓ LFS siap digunakan"
echo ""
echo "Untuk masuk ke chroot:"
echo "  chroot $LFS_MOUNT /bin/bash"
EOF

chmod +x /home/lynx/live/scripts/mount-lfs.sh
