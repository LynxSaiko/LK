#!/bin/bash

# ==========================================================
# KONFIGURASI - SESUAIKAN JALUR DI SINI
# ==========================================================
LFS_MOUNT="/mnt/lfs"               # Lokasi mount sistem LFS 11.2 Anda
WORK_DIR="~/LeakOS-Build"    # Folder pusat pengerjaan
ISO_ROOT="$WORK_DIR/iso_root"       # Folder struktur akhir ISO
INITRD_TREE="$WORK_DIR/initrd_tree" # Folder struktur initramfs

echo "--- Memulai Proses Pembuatan LFS LiveCD ---"

# 1. Persiapan Folder Kerja
mkdir -p $WORK_DIR
mkdir -p $ISO_ROOT/{boot/grub,sources}
mkdir -p $INITRD_TREE/{bin,dev,etc,lib,lib64,mnt/media,mnt/squash,mnt/rw,mnt/merged,/mnt/rw/work,/mnt/rw/upper,proc,root,sbin,sys,usr/bin}

# 2. Buat rootfs.squashfs
echo "[1/4] Membuat SquashFS dari $LFS_MOUNT..."
mkdir -p $LFS_MOUNT/mnt/media
mksquashfs $LFS_MOUNT $ISO_ROOT/sources/rootfs.squashfs -comp zstd -all-root -no-xattrs \
    -e boot \
    -e proc \
    -e sys \
    -e dev \
    -e tmp \
    -e root/gnome \
    -e usr/lib/python3.10 \
    -e var/log \
    -e var/cache \
    -e home/* \
    -e usr/share/doc \
    -e usr/share/info \
    -e usr/share/man \
    -e "*.git" \
    -e "*.zip" \
    -e "*.iso" \
    -e "*.xz" \
    -e "*.deb" \
    -e "*.tar"

# 3. Siapkan Initramfs (Initrd)
echo "[2/4] Menyiapkan Initramfs dengan BusyBox..."

# Download BusyBox static
wget -q --show-progress https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox -O $INITRD_TREE/bin/busybox
chmod +x $INITRD_TREE/bin/busybox

# Install symlinks untuk BusyBox
cd $INITRD_TREE
./bin/busybox --install -s ./bin

# Buat symlink penting
ln -sf bin/busybox sbin/init
ln -sf bin/busybox sbin/switch_root
ln -sf bin/busybox bin/sh

# Buat Node Perangkat Dasar
mknod -m 600 dev/console c 5 1
mknod -m 666 dev/null c 1 3
mknod -m 666 dev/zero c 1 5
mknod -m 666 dev/random c 1 8
mknod -m 660 dev/sr0 b 11 0
mknod -m 660 dev/loop0 b 7 0

cp -a $LFS_MOUNT/lib/modules $(uname -r) $INITRD_TREE/lib/modules/

# Buat Skrip init yang LEBIH SEDERHANA dan HANDAL
cat << 'EOF' > $INITRD_TREE/init
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "========================================="
echo "      LFS LiveCD Initramfs Booting      "
echo "========================================="

# Mount filesystems dasar
mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t tmpfs tmpfs /tmp

# Cari media yang berisi rootfs.squashfs
echo "Mencari media yang berisi rootfs.squashfs..."
for dev in /dev/sr0 /dev/sda /dev/sda1 /dev/sda2 /dev/sdb /dev/sdb1 /dev/sdc /dev/sdc1; do
    if [ -e "$dev" ]; then
        echo "  Mencoba mount $dev..."
        mkdir -p /mnt/media 2>/dev/null
        mount -r -t iso9660,udf,ext4,vfat "$dev" /mnt/media 2>/dev/null
        if [ $? -eq 0 ]; then
            if [ -f "/mnt/media/sources/rootfs.squashfs" ]; then
                echo "  Ditemukan rootfs.squashfs di $dev"
                SQUASH_SOURCE="/mnt/media/sources/rootfs.squashfs"
                break
            fi
            umount /mnt/media 2>/dev/null
        fi
    fi
done

if [ -z "$SQUASH_SOURCE" ]; then
    echo "ERROR: Tidak dapat menemukan rootfs.squashfs!"
    echo "Gagal booting. Masuk ke emergency shell..."
    exec /bin/sh
fi

# Mount squashfs
echo "Mounting squashfs..."
mkdir -p /mnt/squash
mount -t squashfs -o loop "$SQUASH_SOURCE" /mnt/squash

# Setup overlayfs
echo "Setup overlay filesystem..."
mkdir -p /mnt/rw/upper /mnt/rw/work /mnt/merged
mount -t tmpfs tmpfs /mnt/rw
mount -t overlay overlay -o lowerdir=/mnt/squash,upperdir=/mnt/rw/upper,workdir=/mnt/rw/work /mnt/merged

# Pindah ke root baru
echo "Switching to new root..."
cd /mnt/merged

# Pindah mount points
mount --move /dev dev
mount --move /proc proc
mount --move /sys sys
mount --move /tmp tmp 2>/dev/null

# Coba berbagai kemungkinan init
echo "Mencoba menjalankan init..."

# Cek apakah init ada dan executable
if [ -x sbin/init ]; then
    echo "  Menjalankan /sbin/init..."
    exec switch_root . /sbin/init
elif [ -x etc/init ]; then
    echo "  Menjalankan /etc/init..."
    exec switch_root . /etc/init
elif [ -x bin/init ]; then
    echo "  Menjalankan /bin/init..."
    exec switch_root . /bin/init
elif [ -x bin/sh ]; then
    echo "  Menjalankan /bin/sh (fallback)..."
    exec switch_root . /bin/sh
else
    echo "FATAL: Tidak ada init yang ditemukan!"
    echo "Daftar file di root baru:"
    ls -la bin/ sbin/ etc/
    exec /bin/sh
fi
EOF

# Pastikan init executable
chmod +x $INITRD_TREE/init
chmod +x $INITRD_TREE/bin/busybox

# 4. Packing Initrd dengan benar
echo "[3/4] Membungkus Initrd..."
cd $INITRD_TREE
find . -print0 | cpio --null -ov --format=newc | gzip -9 > $ISO_ROOT/boot/initrd.img
echo "Initrd size: $(du -h $ISO_ROOT/boot/initrd.img | cut -f1)"

# 5. Konfigurasi GRUB & Salin Kernel
echo "[4/4] Finalisasi Struktur ISO..."

# Salin kernel - coba beberapa kemungkinan lokasi
if [ -f "$LFS_MOUNT/boot/vmlinuz" ]; then
    cp $LFS_MOUNT/boot/vmlinuz $ISO_ROOT/boot/vmlinuz
else
    echo "WARNING: Kernel tidak ditemukan, cari manual..."
    find $LFS_MOUNT/boot -name "vmlinuz" -exec cp {} $ISO_ROOT/boot/vmlinuz \; 2>/dev/null
fi

# Buat GRUB config dengan lebih banyak opsi
cat << 'EOF' > $ISO_ROOT/boot/grub/grub.cfg
set timeout=10
set default=0

menuentry "LeakOS LiveCD (Normal)" {
    linux /boot/vmlinuz root=/dev/ram0 rw quiet
    initrd /boot/initrd.img
}

menuentry "LeakOS LiveCD (Debug)" {
    linux /boot/vmlinuz root=/dev/ram0 rw
    initrd /boot/initrd.img
}

menuentry "LeakOS LiveCD (Emergency Shell)" {
    linux /boot/vmlinuz root=/dev/ram0 rw init=/bin/sh
    initrd /boot/initrd.img
}
EOF

echo "========================================="
echo "--- PEMBUATAN STRUKTUR ISO SELESAI ---"
echo "========================================="
echo "Folder ISO: $ISO_ROOT"
echo ""
echo "Struktur yang dibuat:"
ls -la $ISO_ROOT/
echo ""
echo "Boot files:"
ls -la $ISO_ROOT/boot/
echo ""
echo "Sources:"
ls -la $ISO_ROOT/sources/
echo ""
echo "Untuk membuat ISO, jalankan:"
echo "grub-mkrescue -o $WORK_DIR/lfs-live.iso $ISO_ROOT"
echo ""
echo "ATAU jika ingin tes boot dari direktori:"
echo "qemu-system-x86_64 -cdrom $WORK_DIR/lfs-live.iso -m 2G"
