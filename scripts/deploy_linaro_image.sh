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
# Embedded Linux Wiki (http://elinux.org/Main_Page)
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

# 4. 重新分区并格式化
print_warning "All data on ${DISK} now will be destroyed!!!"
read -p "Do you want to continue? [y/n] " choice
case $choice in
    y|Y)
        # 删除原有的所有分区
        for i in $(sudo parted -s /dev/$DISK print|awk '/^ / {print $1}')
        do
            sudo parted -s /dev/$DISK rm ${i}
        done

        # 重新分区
        #create a 100MB ext4 partition
        sudo parted -s /dev/$DISK mkpart primary 0% 100MiB
        #create a partition from where we left off to the end of the disk
        sudo parted -s /dev/$DISK mkpart primary 100MiB 100%

        # Format the partition
        sudo mkfs.vfat -n BOOT /dev/${DISK}${PART}1 &> /dev/null
        sudo mkfs.ext4 -L ROOTFS /dev/${DISK}${PART}2 &> /dev/null

        # 挂载磁盘分区
        BOOT_PART=/dev/${DISK}${PART}1
        ROOT_PART=/dev/${DISK}${PART}2

        BOOT_MOUNT_POINT=${ZN_SDCARD_MOUNT_POINT}/boot
        ROOT_MOUNT_POINT=${ZN_SDCARD_MOUNT_POINT}/rootfs

        sudo mount ${BOOT_PART} ${BOOT_MOUNT_POINT}
        sudo mount ${ROOT_PART} ${ROOT_MOUNT_POINT}

        # Install Bootloader
        #sudo cp ${ZN_SDCARD_IMAGES_DIR}/BOOT.bin       ${BOOT_MOUNT_POINT}
        sudo cp ${ZN_SIMG_DIR}/BOOT.bin       ${BOOT_MOUNT_POINT}
        # Copy Kernel Device Tree Binaries
        sudo cp ${ZN_SIMG_DIR}/devicetree.dtb ${BOOT_MOUNT_POINT}
        # Copy Kernel Image
        sudo cp ${ZN_SIMG_DIR}/uImage         ${BOOT_MOUNT_POINT}

        # Plain text file to set U-Boot environmental variables to boot from the SD card
        UENV_TXT=${BOOT_MOUNT_POINT}/uEnv.txt
        # 解决手动修改的问题。
        echo "uenvcmd=run linaro_sdboot"                                                                          > ${UENV_TXT}
        echo ""                                                                                                   >>${UENV_TXT}
        echo "linaro_sdboot=echo Copying Linux from SD to RAM... && \\"                                           >>${UENV_TXT}

        # The files we need are:
        # Linux kernel with modified header for U-Boot
        sudo echo "fatload mmc 0 0x3000000 \${kernel_image} && \\"                                                     >>${UENV_TXT}

        # Device tree blob
        sudo echo "fatload mmc 0 0x2A00000 \${devicetree_image} && \\"                                                 >>${UENV_TXT}

        # Root filesystem
        # 若找到uramdisk.image.gz，则启动基于BusyBox的嵌入式Linux系统
        sudo echo "if fatload mmc 0 0x2000000 \${ramdisk_image}; \\"                                                   >>${UENV_TXT}
        sudo echo "then bootm 0x3000000 0x2000000 0x2A00000; \\"                                                       >>${UENV_TXT}
        # 否则启动Linaro
        sudo echo "else bootm 0x3000000 - 0x2A00000; fi"                                                               >>${UENV_TXT}
        sudo echo ""                                                                                                   >>${UENV_TXT}

        if [ "${ZN_BOARD_NAME}" == "miz702n" ]; then
            sudo echo "bootargs=console=ttyPS0,115200 root=/dev/mmcblk1p2 rw earlyprintk rootfstype=ext4 rootwait"     >>${UENV_TXT}
        elif [ "${ZN_BOARD_NAME}" == "zedboard" ]; then
            sudo echo "bootargs=console=ttyPS0,115200 root=/dev/mmcblk0p2 rw earlyprintk rootfstype=ext4 rootwait"     >>${UENV_TXT}
        else
            sudo echo "bootargs=console=ttyPS0,115200 root=/dev/mmcblk0p2 rw earlyprintk rootfstype=ext4 rootwait"     >>${UENV_TXT}
        fi

        sudo echo ""                                                                                                   >>${UENV_TXT}

        # Creating Linaro Ubuntu Root Filesystem
        # Basic Requirements
        #
        # ARM Cross Compiler – Linaro: http://www.linaro.org
        #     Linaro Toolchain Binaries: http://www.linaro.org/downloads/
        # ARM based rootfs
        #     Debian: https://www.debian.org
        #     Ubuntu: http://www.ubuntu.com
        #
        # Download Linaro Ubtunu ARM rootfs  archive:
        # wget http://releases.linaro.org/ubuntu/images/gnome/15.12/linaro-vivid-gnome-20151215-714.tar.gz

        # Extract the root filesystem onto the SD card.
        printf_info "正在制作文件系统..."
        # Extract the contents of the rootfs directly on to SD media card which is
        # inserted on you linux PC using the below command.
        sudo tar --strip-components=3 -C ${ROOT_MOUNT_POINT} -xzpf   \
            ${ZN_DOWNLOAD_DIR}/linaro-o-ubuntu-desktop-tar-20111219-0.tar.gz \
            binary/boot/filesystem.dir

        # 3.9、Remove microSD/SD card
        sudo sync
        # 方法一：通常，您可以使用 eject <挂载点|设备>命令弹出碟片。
        # eject /dev/${DISK}
        # 方法二：just umount
        sudo umount ${ZN_SDCARD_MOUNT_POINT}/{boot,rootfs}

        ;;

    n|N)
        ;;

    *)
        ;;

esac


# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
