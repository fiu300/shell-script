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
# https://kernelnewbies.org/KernelBuild
# http://www.wiki.xilinx.com/Fetch+Sources
# http://www.wiki.xilinx.com/Build+Kernel
# http://www.wiki.xilinx.com/Build+Kernel#Zynq
# http://processors.wiki.ti.com/index.php/Linux_Kernel_Users_Guide
#
###############################################################################
# => Help and information
usage() {
    echo "Purpose: Compiling and Installing Linux kernel, Device Tree and module"
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
# Compiling and Installing Linux kernel, Device Tree and module
# Task Dependencies (Pre-requisites)
#   * Fetch Sources (Linux sources)
#   * Install Xilinx tools (cross-compilation toolchain)
#   * Build U-Boot (mkimage utility)
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# => Make sure the source is there
if [ "`ls -A ${ZN_KERNEL_DIR}`" = "" ]; then
    error_exit "Can't find the source code of kernel !!!"
else
    cd ${ZN_KERNEL_DIR}
fi

# => Make sure ramdisk.image.gz is there
if [ ! -f "${ZN_TARGET_DIR}/ramdisk.image.gz" ]; then
    if [ ! -f "${ZN_DOWNLOAD_DIR}/ramdisk.image.gz" ]; then
        error_exit "找不到ramdisk.image.gz !!!"
    else
        cp ${ZN_DOWNLOAD_DIR}/ramdisk.image.gz ${ZN_TARGET_DIR}
    fi
fi

# => Make sure the target directory is there
if [ ! "${ZN_TARGET_DIR}" ];then
    error_exit "Can't find the target directory !!!"
fi

# => Compiling the Kernel
print_info "Building the kernel image on the ${ZN_KERNEL_DIR} ..."
echo ${MAKE_JOBS} ${CROSS_COMPILE} 
make ${MAKE_JOBS} ARCH=arm CROSS_COMPIEL=${CROSS_COMPILE} UIMAGE_LOADADDR=0x8000 uImage
if [ $? -eq 0 ]; then
    #############################################################################
    # vmlinux - Linux Kernel ELF file
    # zImage  - compressed kernel image
    # uImage  - zImage plus U-Boot header
    #
    # uImage是在zImage之前加上一个长度为0x40的“头”，说明这个映像文件的类型、加载位
    # 置、生成时间、大小等信息。换句话说，如果直接从uImage的0x40位置开始执行，
    # zImage和uImage没有任何区别。
    #############################################################################
    print_info "Installing the Kernel Image ..."
    cp -a ${ZN_KERNEL_DIR}/arch/arm/boot/zImage ${ZN_TARGET_DIR}
    cp -a ${ZN_KERNEL_DIR}/arch/arm/boot/uImage ${ZN_TARGET_DIR}
    cp -a ${ZN_KERNEL_DIR}/arch/arm/boot/uImage ${ZN_TARGET_DIR}/uImage.bin
else
    error_exit "Kernel Image - Build Failed !!!"
fi

# => Compiling the Device Tree Binaries
#
# 方法一：若设备树放在Kernel目录下，可以使用方法
# print_info "Building the Device Tree Binaries on the ${ZN_KERNEL_DIR}."
# make dtbs
# if [ $? -eq 0 ]; then
#   print_info "Installing the Device Tree Binaries..."
#   cp -a ${ZN_KERNEL_DIR}/arch/arm/boot/dts/${ZN_DTB_NAME} ${ZN_TARGET_DIR}/devicetree.dtb
# else
#   error_exit "Device Tree Binaries - Build Failed!!!"
# fi
#
# 方法二：比较通用的方法
print_info "Building the Device Tree Binaries on the ${ZN_DTS_DIR} ..."
echo "########"
echo ${ZN_DTB_DIR} ${ZN_DTB_NAME} 
echo ${ZN_DTS_DIR} ${ZN_DTS_NAME}
echo "########"

${ZN_DTC_DIR}/dtc -I dts -O dtb -o ${ZN_DTB_DIR}/${ZN_DTB_NAME} ${ZN_DTS_DIR}/${ZN_DTS_NAME}
if [ $? -eq 0 ]; then
    print_info "The Device Tree - Build OK !!!"
else
    error_exit "The Device Tree - Build Failed !!!"
fi

# => Compiling the Kernel Modules
print_info "Building the Kernel Modules on the ${ZN_KERNEL_DIR} ..."
make ${MAKE_JOBS} modules
if [ $? -eq 0 ]; then
    print_info "Installing the Kernel Modules ..."
    # 预处理。。。
    gunzip ${ZN_TARGET_DIR}/ramdisk.image.gz
    chmod u+rwx ${ZN_TARGET_DIR}/ramdisk.image
    sudo mount -o loop ${ZN_TARGET_DIR}/ramdisk.image ${ZN_ROOTFS_MOUNT_POINT}
    sudo rm -rf ${ZN_ROOTFS_MOUNT_POINT}/lib/modules

    # 安装中。。。
    sudo make ${MAKE_JOBS} ARCH=arm INSTALL_MOD_PATH=${ZN_ROOTFS_MOUNT_POINT} modules_install
    if [ $? -eq 0 ]; then
        print_info "The Kernel Modules - Install OK !!!"
    else
        error_exit "The Kernel Modules - Install Failed !!!"
    fi

    # 后处理。。。
    sudo umount ${ZN_ROOTFS_MOUNT_POINT}
    gzip ${ZN_TARGET_DIR}/ramdisk.image

    # --- mkimage ---
    if [ ! $( which mkimage ) ]; then
        error_exit "Missing mkimage command !!!"
    else
        mkimage -A arm -T ramdisk -C gzip -d ${ZN_TARGET_DIR}/ramdisk.image.gz \
            ${ZN_TARGET_DIR}/uramdisk.image.gz
    fi

else
    error_exit "Kernel Modules - Build Failed !!!"
fi

# => Install your custom kernel
# The kernel image and the device tree binary are installed in the boot
# partition whereas the kernel modules, the device firmware and the C header
# files are copied to the root file system. If you are running different Linux
# installations on different partitions of your eMMC or SD storage device with
# the same kernel image you need to install the kernel modules (e.g. by sudo
# make modules_install INSTALL_MOD_PATH=...), the device firmware (sudo make
# firmware_install INSTALL_FW_PATH=...) and the C header files on each of this
# partitions. You can get a list of all make targets and parameters by typing
# make help.
#
# sudo cp ./arch/arm/boot/*(u)*(z)Image ./arch/arm/boot/dts/*.dtb <boot-partition>
# sudo make headers_install INSTALL_HDR_PATH=...
# sudo make modules_install INSTALL_MOD_PATH=...
# sudo make firmware_install INSTALL_FW_PATH=...

#############################################
# make headers_check
# make INSTALL_HDR_PATH=dest headers_install
#############################################

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
