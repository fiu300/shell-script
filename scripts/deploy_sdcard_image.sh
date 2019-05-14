#!/bin/bash -e
###############################################################################
# Copyright (C) 2014 - 2018 by osrc <www.osrc.cn>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Asking for Help:
# Nathan Rossi <nathan.rossi@xilinx.com>
# Michal Simek <michal.simek@xilinx.com>
#
# Reference Materials:
#
###############################################################################

# => Help and information
usage() {
    echo "Purpose: "
    echo "Version: V1.0"
    echo "Usage  : $script_name [option]"
    echo "options:"
    echo "--help: Display this help message"
    exit 0;
}
expr "$*" : ".*--help" > /dev/null && usage

# => Directory containing the running script.
script_dir="$(cd $(dirname ${BASH_SOURCE}) && pwd)"

# => Setting The Development Environment Variables
if [ ! "${CROSS_COMPILE}" ];then
    if [ -f "${script_dir}/settings64.sh" ]; then
        source ${script_dir}/settings64.sh
    else
        printf "Error: Could not find file '${script_dir}/settings64.sh'.\n"
        return 1
    fi
else
    # => Import local function from common.sh
    if [ -f "${script_dir}/common.sh" ]; then
        source ${script_dir}/common.sh
    else
        printf "Error: Could not find file '${script_dir}/common.sh'.\n"
        return 1;
    fi
fi

# => Filename of the running script.
script_name="$(basename ${BASH_SOURCE})"

# => Redirect output to log from inside script
if [ "${ZN_LOGFILE_DIR}" != "" ]; then
    log_file=${ZN_LOGFILE_DIR}/${script_name%.*}.log
    exec &> >(tee "$log_file")
fi

###############################################################################
#
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# 0. Plug in your SD Card to your Linux machine.

# 1、显示磁盘分区信息
print_info "硬盘分区信息"
lsblk --nodeps

# 2、确定SD卡
read -p "请选择磁盘 [hdX|sdX|mmcblkX] 或者输入q退出: " DISK
# 若用户输入的是大写字母，在这里直接转换为小写字母
DISK=`echo $DISK | tr '[:upper:]' '[:lower:]'`
# 2.1、用户选择退出程序
if [ ${DISK} = "q" ];then
    exit 0
fi
# 2.2、用户选择的磁盘是系统所在磁盘
if [ ${DISK} = "hda" ] || [ ${DISK} = "sda" ];then
    error_exit "您输入的是系统存放的硬盘，脚本退出!!!"
fi
# 2.3、
if [ ! -b /dev/${DISK} ]; then
    error_exit "输入有误!!!"
fi
# 2.4 The partition name prefix depends on the device name:
# - /dev/sde -> /dev/sde1
# - /dev/mmcblk0 -> /dev/mmcblk0p1
if echo ${DISK} | grep -q mmcblk ; then
    PART="p"
else
    PART=""
fi

# 3、卸载所选磁盘的所有分区
# Unmount any automatically mounted partitions of the sd card.
print_info "Unmounting all existing partitions on the device..."
for i in $(sudo parted -s /dev/$DISK print|awk '/^ / {print $1}')
do
    [ -n "`df -h | grep /dev/${DISK}${PART}${i}`" ] && { sudo umount /dev/${DISK}${PART}${i}; }
done

# 挂载磁盘分区
BOOT_PART=/dev/${DISK}${PART}1
ROOT_PART=/dev/${DISK}${PART}2

BOOT_MOUNT_POINT=${ZN_SDCARD_MOUNT_POINT}/boot
ROOT_MOUNT_POINT=${ZN_SDCARD_MOUNT_POINT}/rootfs

mkdir -p ${BOOT_MOUNT_POINT} ${ROOT_MOUNT_POINT}

sudo mount -t vfat ${BOOT_PART} ${BOOT_MOUNT_POINT}
# mount ${ROOT_PART} ${ROOT_MOUNT_POINT}


# 5、清除旧镜像
# 5.1. Generate the boot image BOOT.BIN
sudo rm -rf ${BOOT_MOUNT_POINT}/BOOT.bin
# 5.2. uImage: Linux kernel with modified header for U-Boot
sudo rm -rf ${BOOT_MOUNT_POINT}/uImage
# 5.3. Device tree blob
sudo rm -rf ${BOOT_MOUNT_POINT}/devicetree.dtb
# 5.4. Root filesystem
sudo rm -rf ${BOOT_MOUNT_POINT}/uramdisk.image.gz
# 5.5. uEnv.txt: Plain text file to set U-Boot environmental variables to boot from the SD card
sudo rm -rf ${BOOT_MOUNT_POINT}/uEnv.txt

# 6、安装新镜像
sudo cp -r ${ZN_SDCARD_IMG_DIR}/*          ${BOOT_MOUNT_POINT}

# 7、Remove microSD/SD card
sync
# 方法一：通常，您可以使用 eject <挂载点|设备>命令弹出碟片。
# eject /dev/${DISK}
# 方法二：just umount
sudo umount ${ZN_SDCARD_MOUNT_POINT}/boot
# umount ${ZN_SDCARD_MOUNT_POINT}/{boot,rootfs}


# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
