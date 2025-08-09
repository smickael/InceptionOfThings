#!/bin/bash
set -e

VG_NAME="ubuntu-vg"
LV_NAME="ubuntu-lv"

 # 1. Check available space
sudo lvdisplay /dev/$VG_NAME/$LV_NAME

 # 2. Extend logical volume to maximum size
sudo lvextend -l +100%FREE /dev/$VG_NAME/$LV_NAME

 # 3. Resize the filesystem (ext4)
sudo resize2fs /dev/$VG_NAME/$LV_NAME

 # 4. Show new size
df -h /

echo "Root disk space extended to maximum available size!"
