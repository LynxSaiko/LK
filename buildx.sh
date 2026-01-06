#!/bin/bash

# ==========================================================
# KONFIGURASI - SESUAIKAN JALUR DI SINI
# ==========================================================
LFS_MOUNT="/mnt/lfs"               # Lokasi mount sistem LFS 11.2 Anda
WORK_DIR="$HOME/LeakOS-Build"    # Folder pusat pengerjaan
ISO_ROOT="$WORK_DIR/iso_root"       # Folder struktur akhir ISO
INITRD_TREE="$WORK_DIR/initrd_tree" # Folder struktur initramfs

echo "--- Memulai Proses Pembuatan LFS LiveCD ---"

# 1. Persiapan Folder Kerja
mkdir -p $WORD_DIR
mkdir -p $ISO_ROOT/{boot/grub,sources}
mkdir -p $INITRD_TREE/{bin,dev,etc,lib,lib64,mnt/media,mnt/squash,mnt/rw,mnt/merged,/mnt/rw/work,/mnt/rw/upper,proc,sbin,sys}

# 2. Buat rootfs.squashfs
echo "[1/4] Membuat SquashFS dari $LFS_MOUNT..."
# Pastikan mount point media ada di dalam LFS agar sistem punya target mount nanti
sudo mkdir -p $LFS_MOUNT/mnt/media
sudo mksquashfs $LFS_MOUNT $ISO_ROOT/sources/rootfs.squashfs -comp xz -all-root -no-xattrs -e boot proc sys dev tmp root mnt/media usr/lib/python3.10 var/log var/cache home/* usr/share/doc usr/share/info usr/share/man "*.git" "*.zip" "*.tar" "*.iso" "*.deb"

# 3. Siapkan Initramfs (Initrd)
echo "[2/4] Menyiapkan Initramfs dengan BusyBox..."
# Ambil BusyBox Static
if [ -f "/bin/busybox" ]; then
    cp /bin/busybox $INITRD_TREE/bin/
else
    wget https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox -O $INITRD_TREE/bin/busybox
fi
chmod +x $INITRD_TREE/bin/busybox

# Buat Symlinks penting
for tool in sh mount mkdir echo cat cp ls switch_root sleep modprobe vi; do
    $INITRD_TREE/bin/busybox --install -s $INITRD_TREE/bin
done


cp -a $LFS_MOUNT/lib/modules $(uname -r) $INITRD_TREE/lib/modules/

ln -sf ../bin/busybox $INITRD_TREE/sbin/switch_root

# Buat Node Perangkat Dasar
sudo mknod -m 600 $INITRD_TREE/dev/console c 5 1
sudo mknod -m 666 $INITRD_TREE/dev/null c 1 3

# Buat Skrip init di dalam folder initrd_tree
cat << 'EOF' > $INITRD_TREE/init
#!/bin/sh
mount -t devtmpfs devtmpfs /dev
mount -t proc proc /proc
mount -t sysfs sysfs /sys

echo "Booting LFS LiveCD..."
for dev in /dev/sr0 /dev/sd[a-z][1-9] /dev/sd[a-z]; do
    mount -r $dev /mnt/media 2>/dev/null
    if [ -f "/mnt/media/sources/rootfs.squashfs" ]; then
        DEVICE_FOUND=$dev
        break
    fi
    umount /mnt/media 2>/dev/null
done

mount -t squashfs -o loop /mnt/media/sources/rootfs.squashfs /mnt/squash
mount -t tmpfs tmpfs /mnt/rw
mkdir -p /mnt/rw/upper /mnt/rw/work
mount -t overlay overlay -o lowerdir=/mnt/squash,upperdir=/mnt/rw/upper,workdir=/mnt/rw/work /mnt/merged

mount --move /dev /mnt/merged/dev
mount --move /proc /mnt/merged/proc
mount --move /sys /mnt/merged/sys
mount --move /mnt/media /mnt/merged/mnt/media 2>/dev/null

#exec switch_root /mnt/merged /sbin/init
exec switch_root /mnt/merged /sbin/init \
    || exec switch_root /mnt/merged /etc/init \
    || exec switch_root /mnt/merged /bin/init \
    || exec switch_root /mnt/merged /bin/sh \
    || echo "FATAL: Tidak ada init yang bisa dijalankan!" && exec /bin/sh
EOF

chmod +x $INITRD_TREE/init

# Packing Initrd
echo "[3/4] Membungkus Initrd..."
cd $INITRD_TREE
find . | cpio -o -H newc | gzip > $ISO_ROOT/boot/initrd.img
cd $WORK_DIR

# 4. Konfigurasi GRUB & Salin Kernel
echo "[4/4] Finalisasi Struktur ISO..."
# Salin kernel dari LFS ke ISO (Sesuaikan nama vmlinuz Anda)
cp $LFS_MOUNT/boot/vmlinuz $ISO_ROOT/boot/vmlinuz

cat << EOF > $ISO_ROOT/boot/grub/grub.cfg
set default=0
set timeout=5
menuentry "LFS 11.2 LiveCD" {
    linux /boot/vmlinuz root=/dev/ram0 rw
    initrd /boot/initrd.img
}
EOF

echo "--- SEMUA SELESAI ---"
echo "Folder ISO siap di: $ISO_ROOT"
echo "Langkah terakhir: jalankan 'grub-mkrescue -o lfs.iso $ISO_ROOT'"
