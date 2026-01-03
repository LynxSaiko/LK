#!/bin/bash
# Script untuk unmount LFS bind mounts

LFS_MOUNT="/mnt/lfs"  # Sesuaikan dengan mount point LFS Anda

echo "Unmounting LFS bind mounts..."

# Cek apakah mount point ada
if [ ! -d "$LFS_MOUNT" ]; then
    echo "Error: LFS mount point $LFS_MOUNT tidak ditemukan!"
    exit 1
fi

# Unmount dalam urutan yang aman
if mountpoint -q "$LFS_MOUNT/run"; then
    echo "Unmounting $LFS_MOUNT/run..."
    umount -v "$LFS_MOUNT/run" || umount -l "$LFS_MOUNT/run"
else
    echo "$LFS_MOUNT/run sudah unmounted"
fi

if mountpoint -q "$LFS_MOUNT/sys"; then
    echo "Unmounting $LFS_MOUNT/sys..."
    umount -v "$LFS_MOUNT/sys" || umount -l "$LFS_MOUNT/sys"
else
    echo "$LFS_MOUNT/sys sudah unmounted"
fi

if mountpoint -q "$LFS_MOUNT/proc"; then
    echo "Unmounting $LFS_MOUNT/proc..."
    umount -v "$LFS_MOUNT/proc" || umount -l "$LFS_MOUNT/proc"
else
    echo "$LFS_MOUNT/proc sudah unmounted"
fi

if mountpoint -q "$LFS_MOUNT/dev/pts"; then
    echo "Unmounting $LFS_MOUNT/dev/pts..."
    umount -v "$LFS_MOUNT/dev/pts" || umount -l "$LFS_MOUNT/dev/pts"
else
    echo "$LFS_MOUNT/dev/pts sudah unmounted"
fi

if mountpoint -q "$LFS_MOUNT/dev"; then
    echo "Unmounting $LFS_MOUNT/dev..."
    umount -v "$LFS_MOUNT/dev" || umount -l "$LFS_MOUNT/dev"
else
    echo "$LFS_MOUNT/dev sudah unmounted"
fi

echo "Semua bind mounts telah di-unmount!"
