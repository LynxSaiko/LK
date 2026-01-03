#!/bin/bash
# virtualbox-bootable-iso.sh

SOURCE="/home/lynx/live/temp/iso-structure"
OUTPUT="/home/lynx/live/iso/lfs-virtualbox.iso"
TEMP_DIR="/tmp/vbox-iso"

echo "=== Creating VirtualBox-Compatible ISO ==="

# Install dependencies
echo "Installing required tools..."
sudo apt-get update
sudo apt-get install -y \
    genisoimage \
    xorriso \
    syslinux \
    isolinux \
    mtools \
    grub-common \
    grub-pc-bin 2>/dev/null || true

# Setup working directory
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cp -a "$SOURCE"/* "$TEMP_DIR/" 2>/dev/null || true

# Method 1: Buat ISO bootable lengkap
echo "Method 1: Creating bootable ISO..."

# Buat direktori boot
mkdir -p "$TEMP_DIR/boot/grub" "$TEMP_DIR/isolinux"

# File konfigurasi isolinux
cat > "$TEMP_DIR/isolinux/isolinux.cfg" << "ISOCFG"
DEFAULT live
TIMEOUT 300
PROMPT 0
UI menu.c32

MENU TITLE LFS 11.2 Live Boot
MENU BACKGROUND splash.png

LABEL live
  MENU LABEL ^Start LFS Live System
  MENU DEFAULT
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initrd.img boot=live quiet splash

LABEL live-text
  MENU LABEL Start LFS Live (Text Mode)
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initrd.img boot=live 3

LABEL memtest
  MENU LABEL ^Memory Test
  KERNEL /boot/memtest
  APPEND -

LABEL hdt
  MENU LABEL ^Hardware Detection Tool
  COM32 hdt.c32

LABEL reboot
  MENU LABEL ^Reboot
  COM32 reboot.c32

LABEL poweroff
  MENU LABEL ^Power Off
  COM32 poweroff.c32
ISOCFG

# Copy syslinux files
SYS_FILES=(
    "/usr/lib/syslinux/isolinux.bin"
    "/usr/lib/syslinux/menu.c32"
    "/usr/lib/syslinux/vesamenu.c32"
    "/usr/lib/syslinux/ldlinux.c32"
    "/usr/lib/syslinux/libutil.c32"
    "/usr/lib/syslinux/reboot.c32"
    "/usr/lib/syslinux/poweroff.c32"
    "/usr/lib/syslinux/hdt.c32"
    "/usr/lib/syslinux/chain.c32"
)

for file in "${SYS_FILES[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$TEMP_DIR/isolinux/"
    fi
done

# Buat splash screen (simple text)
echo "LFS 11.2 Live System" > "$TEMP_DIR/isolinux/splash.txt"

# Buat ISO
cd "$TEMP_DIR"
genisoimage \
    -V "LFS_VIRTUALBOX" \
    -J \
    -R \
    -c "isolinux/boot.cat" \
    -b "isolinux/isolinux.bin" \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e "boot/grub/efi.img" \
    -no-emul-boot \
    -o "$OUTPUT" \
    . 2>/dev/null

# Buat hybrid MBR
if [ -f "$OUTPUT" ]; then
    echo "Making ISO hybrid..."
    
    if command -v isohybrid >/dev/null 2>&1; then
        isohybrid --uefi "$OUTPUT" 2>/dev/null || isohybrid "$OUTPUT"
    else
        # Manual hybrid
        dd if=/usr/lib/syslinux/mbr/isohdpfx.bin of="$OUTPUT" bs=440 count=1 conv=notrunc 2>/dev/null
    fi
    
    # Verifikasi
    echo -e "\n✅ VERIFICATION"
    echo "ISO: $OUTPUT"
    echo "Size: $(du -h "$OUTPUT" | cut -f1)"
    
    # Cek bootable
    echo -e "\n🔍 Boot check:"
    dd if="$OUTPUT" bs=1 count=2 skip=510 2>/dev/null | xxd -p | grep -q "55aa" && \
        echo "✓ Boot signature: 55 AA present" || \
        echo "✗ No boot signature"
    
    echo -e "\n🎮 VirtualBox Setup:"
    echo "1. Create New VM"
    echo "2. Type: Linux"
    echo "3. Version: Other Linux (64-bit)"
    echo "4. Memory: 2048 MB or more"
    echo "5. Create virtual disk"
    echo "6. Settings → Storage → Empty → Choose ISO: $OUTPUT"
    echo "7. Start VM"
    
    echo -e "\n⚡ Quick test:"
    echo "qemu-system-x86_64 -cdrom \"$OUTPUT\" -m 2G -vga std"
else
    echo "❌ ISO creation failed"
    exit 1
fi
