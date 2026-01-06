#!/bin/bash

# ==========================================================
# KONFIGURASI - SESUAIKAN JALUR DI SINI
# ==========================================================
WORK_DIR="~/LeakOS-Build"    # Folder pusat pengerjaan
ISO_ROOT="$WORK_DIR/iso_root"       # Folder struktur akhir ISO
grub-mkrescue -o $WORK_DIR/lfs-live.iso $ISO_ROOT -iso-level 3
