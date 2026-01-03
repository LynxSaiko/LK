#!/bin/bash
# build-15gb-direct.sh

echo "=== Building 15GB ISO Directly ==="

SOURCE_DIR="/home/lynx/live/temp/iso-structure"
OUTPUT_ISO="/home/lynx/live/iso/lfs-15gb.iso"

# Cek space dulu
echo "Checking disk space..."
AVAILABLE_SPACE=$(df -B1 "$SOURCE_DIR" | tail -1 | awk '{print $4}')
SOURCE_SIZE=$(du -sb "$SOURCE_DIR" | cut -f1)

echo "Source size: $((SOURCE_SIZE / 1024 / 1024 / 1024)) GB"
echo "Available space: $((AVAILABLE_SPACE / 1024 / 1024 / 1024)) GB"

if [ "$AVAILABLE_SPACE" -lt "$SOURCE_SIZE" ]; then
    echo "ERROR: Not enough space!"
    echo "Need at least $((SOURCE_SIZE / 1024 / 1024 / 1024)) GB"
    exit 1
fi

# Pastikan di directory source
cd "$SOURCE_DIR" || { echo "Cannot cd to $SOURCE_DIR"; exit 1; }

# Cek file penting
echo "Checking essential files..."
if [ ! -f "boot/vmlinuz" ]; then
    echo "WARNING: Kernel not found at boot/vmlinuz"
fi

if [ ! -f "live/filesystem.squashfs" ]; then
    echo "WARNING: squashfs not found at live/filesystem.squashfs"
fi

# Buat boot files jika tidak ada
echo "Preparing boot files..."
mkdir -p boot/grub isolinux

# Buat GRUB config
cat > boot/grub/grub.cfg << "GRUBCFG"
set timeout=10
set default=0

menuentry "LFS 11.2 Live (15GB)" {
    linux /boot/vmlinuz boot=live quiet
    initrd /boot/initrd.img
}

menuentry "LFS 11.2 (Debug Mode)" {
    linux /boot/vmlinuz boot=live debug
    initrd /boot/initrd.img
}
GRUBCFG

# Buat isolinux config
cat > isolinux/isolinux.cfg << "ISOCFG"
DEFAULT live
TIMEOUT 300
PROMPT 0

LABEL live
  MENU LABEL Start LFS Live
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initrd.img boot=live quiet
ISOCFG

# Copy isolinux.bin jika ada
if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
    cp /usr/lib/ISOLINUX/isolinux.bin isolinux/
fi

# Buat ISO dengan xorriso (mendukung file besar)
echo "Creating ISO with xorriso (this may take a while)..."

# Method 1: Dengan UDF filesystem untuk file >4GB
xorriso -as mkisofs \
    -volid "LFS_15GB" \
    -V "LFS_15GB" \
    -udf \
    -iso-level 3 \
    -rock \
    -joliet \
    -rational-rock \
    -joliet-long \
    -allow-limited-size \
    -full-iso9660-filenames \
    -cache-inodes \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -c "isolinux/boot.cat" \
    -b "isolinux/isolinux.bin" \
    -o "$OUTPUT_ISO" \
    . 2>&1 | tee /tmp/iso-build.log

# Jika gagal, coba method 2 tanpa boot sector dulu
if [ $? -ne 0 ] || [ ! -f "$OUTPUT_ISO" ]; then
    echo "Method 1 failed, trying simple UDF..."
    
    # Buat ISO tanpa boot sector dulu
    xorriso -as mkisofs \
        -volid "LFS_DATA" \
        -udf \
        -iso-level 3 \
        -allow-limited-size \
        -o "$OUTPUT_ISO" \
        . 2>&1 | tee -a /tmp/iso-build.log
        
    if [ -f "$OUTPUT_ISO" ]; then
        echo "Data ISO created, adding boot sector..."
        # Tambah boot sector setelah ISO dibuat
        dd if=/usr/lib/syslinux/mbr/isohdpfx.bin of="$OUTPUT_ISO" bs=440 count=1 conv=notrunc
    fi
fi

# Buat ISO hybrid untuk USB boot
if [ -f "$OUTPUT_ISO" ]; then
    echo "Making ISO hybrid..."
    if command -v isohybrid >/dev/null 2>&1; then
        isohybrid "$OUTPUT_ISO" 2>/dev/null || true
    fi
fi

# Verifikasi
if [ -f "$OUTPUT_ISO" ]; then
    echo ""
    echo "✅ SUCCESS: 15GB ISO created!"
    echo "   Location: $OUTPUT_ISO"
    echo "   Size: $(du -h "$OUTPUT_ISO" | cut -f1)"
    
    echo -e "\n📊 ISO Information:"
    file "$OUTPUT_ISO"
    
    echo -e "\n🔍 Boot check:"
    dd if="$OUTPUT_ISO" bs=1 count=2 skip=510 2>/dev/null | xxd -p | grep -q "55aa" && \
        echo "   ✓ Boot signature: 55 AA" || \
        echo "   ✗ No boot signature"
        
    echo -e "\n🎯 Ready for VirtualBox!"
else
    echo "❌ ISO creation failed"
    echo "Check log: /tmp/iso-build.log"
    exit 1
fi
