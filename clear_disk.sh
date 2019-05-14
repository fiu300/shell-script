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
# => Help and information
usage() {
    echo "Purpose: Remove partition from SD card / USB drive"
    echo "Version: V2018.03"
    echo "Usage	 : $(basename ${BASH_SOURCE}) [option]"
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
# Remove partition from SD card / USB drive
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

print_warn "All data on ${DISK} now will be destroyed!!!"
read -p "Do you want to continue? [y/n] " choice
case $choice in
    y|Y)
        if type parted >/dev/null 2>&1; then
            # 1. The partition name prefix depends on the device name:
            # - /dev/sde -> /dev/sde1
            # - /dev/mmcblk0 -> /dev/mmcblk0p1
            if echo ${DISK} | grep -q mmcblk ; then
                PART="p"
            else
                PART=""
            fi

            # 2. Check if the card device has mounted partitions
            # https://wiki.krtkl.com/index.php?title=SD_Card
            if [ $(mount | grep -c "/dev/$DISK$PART[0-9]*") != "0" ]; then
                echo "SD card has mounted partitions -> unmounting"
                mount | grep -o "/dev/$DISK$PART[0-9]*" | xargs sudo umount -n

                if [ $? -ne 0 ]; then
                    echo "[ERROR]: Failed to unmount existing partitions"
                    exit
                fi

                sleep 3
            fi

            # 3. 删除所选磁盘的所有分区
            print_info "Remove partition from SD card / USB drive..."
            for i in $(sudo parted -s /dev/$DISK print|awk '/^ / {print $1}')
            do
                sudo parted -s /dev/$DISK rm ${i}
            done
        else
            # Understanding MBR size
            #
            # The mbr size is as follows in bytes:
            #
            # Where,446 + 64 + 2 = 512
            #
            #     446 bytes – Bootstrap.
            #     64 bytes – Partition table.
            #     2 bytes – Signature.
            #
            # Option #1: Command to delete mbr including all partitions
            print_info "Deleting MBR including all partitions on ${DISK} ..."
            dd if=/dev/zero of=/dev/${DISK} bs=512 count=1

            # Option #2: Command to delete mbr only
            # print_info "Deleting MBR, but not your partitions on ${DISK} ..."
            # dd if=/dev/zero of=/dev/${DISK} bs=446 count=1

            # If you wish to keep the partition table, run:
            # sudo dd if=/dev/zero of=/dev/${DISK} bs=1k count=1023 seek=1
        fi

        ;;
    n|N)
        ;;
    *)
        ;;
esac

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
