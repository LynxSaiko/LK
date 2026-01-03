#!/bin/bash
# geniso-large.sh

SOURCE="/home/lynx/live/temp/iso-structure"
OUTPUT="/home/lynx/live/iso/lfs-large.iso"

# Parameter untuk file besar
genisoimage \
  -V "LFS_LARGE" \
  -J \
  -R \
  -joliet-long \
  -iso-level 3 \
  -allow-lowercase \
  -allow-multidot \
  -no-iso-translate \
  -max-iso9660-filenames \
  -udf \
  -allow-limited-size \
  -o "$OUTPUT" \
  "$SOURCE"

# Verifikasi
if [ -f "$OUTPUT" ]; then
    echo "Success! ISO size: $(du -h "$OUTPUT" | cut -f1)"
    echo "ISO created at: $OUTPUT"
else
    echo "Failed to create ISO"
fi
