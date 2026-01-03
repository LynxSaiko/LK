cat > /home/lynx/live/scripts/mkinitrd.sh << 'EOF'
#!/bin/bash
# Buat initrd di /home/lynx/live/initrd/

set -e

BASE_DIR="/home/lynx/live"
INITRD_DIR="$BASE_DIR/initrd"
WORK_DIR="$BASE_DIR/temp/initrd-work"
LFS_MOUNT="/mnt/lfs"

echo "=== MEMBUAT INITRD ==="

# Bersihkan dan buat struktur
rm -rf "$WORK_DIR" "$INITRD_DIR"
mkdir -p "$WORK_DIR" "$INITRD_DIR"
mkdir -p "$WORK_DIR/rootfs"{/bin,/dev,/etc,/lib,/mnt,/proc,/run,/sbin,/sys,/tmp}

# Salin binary penting dari LFS
echo "1. Menyalin binaries..."
BINS=("bash" "sh" "ls" "cp" "mv" "rm" "mkdir" "rmdir" "cat" "echo"
      "mount" "umount" "switch_root" "modprobe" "insmod" "lsmod"
      "find" "grep" "sleep" "test" "[" "dmesg" "chroot")

for bin in "${BINS[@]}"; do
    for path in /bin /sbin /usr/bin /usr/sbin; do
        if [ -f "$LFS_MOUNT$path/$bin" ]; then
            cp -v "$LFS_MOUNT$path/$bin" "$WORK_DIR/rootfs$path/" 2>/dev/null
            break
        fi
    done
done

# Salin library
echo "2. Menyalin libraries..."
copy_libs() {
    local binary="$1"
    [ ! -f "$binary" ] && return 0
    
    ldd "$binary" 2>/dev/null | grep -o '/[^ ]*.so[^ ]*' | while read lib; do
        if [ -f "$LFS_MOUNT$lib" ]; then
            mkdir -p "$WORK_DIR/rootfs$(dirname "$lib")"
            cp -n "$LFS_MOUNT$lib" "$WORK_DIR/rootfs$lib" 2>/dev/null || true
        fi
    done
}

# Copy libs untuk semua binary
find "$WORK_DIR/rootfs/bin" "$WORK_DIR/rootfs/sbin" \
     -type f 2>/dev/null | while read bin; do
    copy_libs "$bin"
done

# Buat device nodes
echo "3. Membuat device nodes..."
mknod -m 622 "$WORK_DIR/rootfs/dev/console" c 5 1
mknod -m 666 "$WORK_DIR/rootfs/dev/null" c 1 3
mknod -m 666 "$WORK_DIR/rootfs/dev/zero" c 1 5
mknod -m 666 "$WORK_DIR/rootfs/dev/random" c 1 8
mknod -m 666 "$WORK_DIR/rootfs/dev/tty" c 5 0
mknod -m 660 "$WORK_DIR/rootfs/dev/loop0" b 7 0
mknod -m 660 "$WORK_DIR/rootfs/dev/sda" b 8 0
mknod -m 660 "$WORK_DIR/rootfs/dev/sr0" b 11 0

# Buat init script
echo "4. Membuat init script..."
cat > "$WORK_DIR/rootfs/init" << "INITEOF"
#!/bin/bash

# Mount filesystems dasar
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Setup console
exec 0</dev/console
exec 1>/dev/console
exec 2>/dev/console

echo "========================================"
echo "        LFS 11.2 Live Initrd"
echo "========================================"

# Load modules
echo "Memuat kernel modules..."
for mod in squashfs overlay loop; do
    modprobe $mod 2>/dev/null && echo "✓ $mod" || echo "✗ $mod"
done

# Cari live media
echo "Mencari live media..."
ISO_MOUNT=""
for dev in /dev/sr0 /dev/sda1 /dev/sdb1 /dev/vda1; do
    if [ -b "$dev" ]; then
        echo "  Mencoba $dev..."
        mkdir -p /mnt/iso
        if mount -t iso9660 "$dev" /mnt/iso 2>/dev/null; then
            ISO_MOUNT="/mnt/iso"
            break
        fi
        umount /mnt/iso 2>/dev/null
    fi
done

if [ -n "$ISO_MOUNT" ] && [ -f "$ISO_MOUNT/live/filesystem.squashfs" ]; then
    echo "✓ Live system ditemukan"
    
    # Mount squashfs
    mkdir -p /squashfs
    mount -t squashfs "$ISO_MOUNT/live/filesystem.squashfs" /squashfs
    
    # Buat overlay
    mkdir -p /overlay /newroot
    mount -t tmpfs tmpfs /overlay
    mkdir -p /overlay/{upper,work}
    
    mount -t overlay overlay \
        -o lowerdir=/squashfs,upperdir=/overlay/upper,workdir=/overlay/work \
        /newroot
    
    # Pindah mounts
    mount --move /proc /newroot/proc
    mount --move /sys /newroot/sys
    mount --move /dev /newroot/dev
    
    # Cleanup
    umount /overlay
    umount /squashfs
    umount "$ISO_MOUNT"
    
    echo "Beralih ke root filesystem..."
    exec switch_root /newroot /sbin/init
else
    echo "ERROR: Live system tidak ditemukan!"
    echo "Masuk ke emergency shell..."
    export PS1="(initrd) \w# "
    exec /bin/bash
fi
INITEOF

chmod +x "$WORK_DIR/rootfs/init"

# Buat symlink
ln -sf bash "$WORK_DIR/rootfs/bin/sh"

# Package initrd
echo "5. Membuat initrd.img..."
cd "$WORK_DIR/rootfs"
find . | cpio -H newc -o 2>/dev/null | gzip -9 > "$INITRD_DIR/initrd.img"

# Buat versi untuk LFS boot juga
cp "$INITRD_DIR/initrd.img" "$LFS_MOUNT/boot/initrd.img"

echo "✓ Initrd selesai: $INITRD_DIR/initrd.img"
echo "  Size: $(du -h "$INITRD_DIR/initrd.img" | cut -f1)"
EOF

chmod +x /home/lynx/live/scripts/mkinitrd.sh
