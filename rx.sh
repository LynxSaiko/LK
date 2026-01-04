#!/bin/bash

# ==========================================================
# KONFIGURASI
# ==========================================================
LFS_MOUNT="/mnt/lfs"
WORK_DIR="$HOME/LFS_BUILD_SPACE"
ISO_ROOT="$WORK_DIR/iso_root"
INITRD_TREE="$WORK_DIR/initrd_tree"

echo "=== LFS LIVECD BUILDER (FIXED) ==="



# 2. Setup INITRD dengan BusyBox
echo "[2/5] Setting up initrd..."

# Download atau copy busybox static
if [ -f "/bin/busybox" ]; then
    BUSYBOX_SRC="/bin/busybox"
elif which busybox >/dev/null 2>&1; then
    BUSYBOX_SRC=$(which busybox)
else
    echo "  Downloading busybox static..."
    wget -q https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox \
        -O "$INITRD_TREE/bin/busybox"
    BUSYBOX_SRC="$INITRD_TREE/bin/busybox"
fi

if [ -f "$BUSYBOX_SRC" ]; then
    cp "$BUSYBOX_SRC" "$INITRD_TREE/bin/busybox"
    chmod +x "$INITRD_TREE/bin/busybox"
else
    echo "ERROR: Cannot find or download busybox!"
    exit 1
fi

# Buat symlinks CRITICAL
echo "  Creating symlinks..."
cd "$INITRD_TREE/bin"
./busybox --list | while read applet; do
    ln -sf busybox "$applet" 2>/dev/null || true
done
cd -

# Pastikan symlink penting ada
ln -sf ../bin/busybox "$INITRD_TREE/sbin/switch_root" 2>/dev/null || true
ln -sf busybox "$INITRD_TREE/bin/sh" 2>/dev/null || true

# 3. Device nodes
echo "[3/5] Creating device nodes..."
sudo mknod -m 622 "$INITRD_TREE/dev/console" c 5 1
sudo mknod -m 666 "$INITRD_TREE/dev/null" c 1 3
sudo mknod -m 666 "$INITRD_TREE/dev/zero" c 1 5
sudo mknod -m 666 "$INITRD_TREE/dev/random" c 1 8
sudo mknod -m 660 "$INITRD_TREE/dev/sr0" b 11 0
sudo mknod -m 660 "$INITRD_TREE/dev/loop0" b 7 0

# 4. Buat init script yang BENAR
echo "[4/5] Creating init script..."
cat > "$INITRD_TREE/init" << "INITEOF"
#!/bin/busybox sh

# Mount basic filesystems
/bin/busybox mount -t devtmpfs devtmpfs /dev
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys

# Setup console
exec 0</dev/console
exec 1>/dev/console
exec 2>/dev/console

echo "========================================"
echo "        LFS 11.2 LiveCD"
echo "========================================"

# Load modules
echo "Loading modules..."
for mod in loop squashfs overlay; do
    /bin/busybox modprobe $mod 2>/dev/null && echo "  ✓ $mod" || echo "  ✗ $mod"
done

# Find live media
echo "Searching for live media..."
FOUND=0
for dev in /dev/sr0 /dev/sda /dev/sdb /dev/vda; do
    if [ -b "$dev" ]; then
        echo "  Trying $dev..."
        /bin/busybox mkdir -p /mnt/media
        if /bin/busybox mount -r -t iso9660 $dev /mnt/media 2>/dev/null; then
            if [ -f "/mnt/media/sources/rootfs.squashfs" ]; then
                echo "    Found rootfs.squashfs!"
                FOUND=1
                break
            else
                echo "    No squashfs found"
                /bin/busybox umount /mnt/media 2>/dev/null
            fi
        fi
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "ERROR: No live system found!"
    echo "Dropping to emergency shell..."
    export PS1="(initrd)# "
    exec /bin/busybox sh
fi

# Mount squashfs
echo "Mounting squashfs..."
/bin/busybox mkdir -p /mnt/squash
/bin/busybox mount -t squashfs -o ro /mnt/media/sources/rootfs.squashfs /mnt/squash

# Setup overlay
echo "Setting up overlay..."
/bin/busybox mkdir -p /mnt/rw /mnt/merged
/bin/busybox mount -t tmpfs tmpfs /mnt/rw
/bin/busybox mkdir -p /mnt/rw/{upper,work}
/bin/busybox mount -t overlay overlay \
    -o lowerdir=/mnt/squash,upperdir=/mnt/rw/upper,workdir=/mnt/rw/work \
    /mnt/merged

# Move mounts
/bin/busybox mount --move /dev /mnt/merged/dev
/bin/busybox mount --move /proc /mnt/merged/proc
/bin/busybox mount --move /sys /mnt/merged/sys

# Verify /sbin/init exists
if [ ! -x "/mnt/merged/sbin/init" ]; then
    echo "ERROR: /sbin/init not found!"
    echo "Contents of /mnt/merged/sbin/:"
    /bin/busybox ls -la /mnt/merged/sbin/
    echo "Dropping to shell..."
    exec /bin/busybox sh
fi

# Switch root
echo "Switching to new root..."
exec /bin/busybox switch_root /mnt/merged /sbin/init
INITEOF

chmod +x "$INITRD_TREE/init"

# 5. Package initrd dengan VERIFIKASI
echo "[5/5] Packaging initrd..."
cd "$INITRD_TREE"
echo "  Contents before packaging:"
ls -la
echo "  init file:"
head -5 init
echo "  Checking init executable:"
file init
ls -la bin/busybox

echo "  Creating cpio archive..."
find . 2>/dev/null | cpio -H newc -o 2>/dev/null | gzip -9 > "$ISO_ROOT/boot/initrd.img"

# Verify the initrd
echo "  Verifying initrd..."
mkdir -p /tmp/verify-initrd
cd /tmp/verify-initrd
if zcat "$ISO_ROOT/boot/initrd.img" | cpio -idmv 2>/dev/null; then
    echo "  ✓ Initrd extracts successfully"
    if [ -x "init" ]; then
        echo "  ✓ init is executable"
        head -3 init
    else
        echo "  ✗ init not executable or missing!"
    fi
else
    echo "  ✗ Initrd extraction failed!"
fi
cd -
rm -rf /tmp/verify-initrd

# 6. Copy kernel
echo "[6/6] Copying kernel..."
KERNEL=$(find "$LFS_MOUNT/boot" -name "vmlinuz-*" -type f | head -1)
if [ -n "$KERNEL" ]; then
    cp "$KERNEL" "$ISO_ROOT/boot/vmlinuz"
    echo "  Kernel: $(basename "$KERNEL")"
else
    echo "  WARNING: No kernel found! Trying from host..."
    cp /boot/vmlinuz-* "$ISO_ROOT/boot/vmlinuz" 2>/dev/null || true
fi

# 7. GRUB config
cat > "$ISO_ROOT/boot/grub/grub.cfg" << GRUBEOF
set timeout=5
set default=0

menuentry "LFS 11.2 LiveCD" {
    linux /boot/vmlinuz root=live:CDLABEL=LFS_LIVE rw quiet
    initrd /boot/initrd.img
}

menuentry "LFS LiveCD (Debug)" {
    linux /boot/vmlinuz root=live:CDLABEL=LFS_LIVE rw debug
    initrd /boot/initrd.img
}
GRUBEOF

echo ""
echo "=== BUILD COMPLETE ==="
echo "ISO structure at: $ISO_ROOT"
echo ""
echo "Create ISO with:"
echo "  grub-mkrescue -o lfs-live.iso $ISO_ROOT -- -volid 'LFS_LIVE'"
echo ""
echo "Test initrd:"
echo "  zcat $ISO_ROOT/boot/initrd.img | cpio -t | head -20"
EOF

chmod +x /home/lynx/live/scripts/build-livecd-fixed.sh
