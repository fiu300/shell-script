#!/bin/bash -e
###############################################################################
#
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
LANG=C
# => Help and information
usage() {
    echo "Purpose: Make 2 Partition SD Card"
    echo "Version: V2018.03"
    echo "Usage  : $(basename ${BASH_SOURCE}) [option]"
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
        echo "[ERROR] Could not find file '${script_dir}/settings64.sh' !!!"
        exit 1
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
# Purpose: Make 2 Partition SD Card
#
# listing existing partitions:
# sudo parted -s /dev/$DISK print|awk '/^ / {print $1}'
#
# finding the size of the disk:
# sudo parted -s /dev/$DISK print|awk '/^Disk/ {print $3}'|sed 's/[Mm][Bb]//'
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

#  重新分区并格式化
print_warn "All data on ${DISK} now will be destroyed!!!"
read -p "Do you want to continue? [y/n] " choice
case $choice in
    y|Y)
        # 1. The partition name prefix depends on the device name:
        # - /dev/sde -> /dev/sde1
        # - /dev/mmcblk0 -> /dev/mmcblk0p1
        if echo ${DISK} | grep -q mmcblk ; then
            PART="p"
        else
            PART=""
        fi
        # 2. 卸载所选磁盘的所有分区
        print_info "Unmount any automatically mounted partitions of the sd card..."
        # listing existing partitions:
        for i in $(sudo parted -s /dev/$DISK print|awk '/^ / {print $1}')
        do
            [ -n "`df -h | grep /dev/${DISK}${PART}${i}`" ] && { sudo umount /dev/${DISK}${PART}${i}; }
        done

        # 3. 删除所选磁盘的所有分区
        print_info "Remove partition from SD card / USB drive..."
        for i in $(sudo parted -s /dev/$DISK print|awk '/^ / {print $1}')
        do
            sudo parted -s /dev/$DISK rm ${i}
        done

        # 4. 重新分区
        # Wipe the SD Card partition table
        sudo parted -s /dev/$DISK mklabel msdos
        # Create a 100MB ext4 partition
        sudo parted -s /dev/$DISK mkpart primary 0% 100MiB
        # Create a partition from where we left off to the end of the disk
        sudo parted -s /dev/$DISK mkpart primary 100MiB 100%

        # Format the partition
        sudo mkfs.vfat -n "BOOT" /dev/${DISK}${PART}1 &> /dev/null
        sudo mkfs.ext4 -L ROOTFS /dev/${DISK}${PART}2 &> /dev/null

        # 5. see the list of paritions by typing the following command:
        # 5.1. Using /proc/partitions
        # cat /proc/partitions
        # 5.2. Using df
        # The df command will only show you mounted partitions, but can give you useful information.
        # 5.3. Using mount
        # The mount command will only show you mounted partitions, but will give you all the details of the mount
        # mount -l
        # 5.4. Using fdisk
        # fdisk -l
        # 5.5. Using blkid
        # blkid
        # 5.6. Using lsblk
        # lsblk

        ;;
    n|N)
        ;;
    *)
        ;;
esac


# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
