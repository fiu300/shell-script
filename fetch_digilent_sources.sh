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
# http://www.wiki.xilinx.com/Fetch+Sources
#
###############################################################################
# => Help and information
usage() {
    echo "Purpose: Fetch Digilent Sources"
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
# Fetch Digilent Sources
# Note:
# PetaLinux 2015.4 contains the following build collateral:
# * Linux Kernel Version 4.0 (Git tag: xilinx-v2015.4)
# * U-Boot Version 2015.07 (Git tag: xilinx-v2015.4)
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

## This script requires "wget".
type wget >/dev/null 2>&1 || { sudo apt-get update; sudo apt-get install wget; }

# 1. Getting the U-Boot Source Code
print_info "Getting the U-Boot Source Code..."
# ZN_UBOOT_TAG=digilent-v2016.03
ZN_UBOOT_TAG=digilent-v2016.07
ZN_UBOOT_TAR=${ZN_DOWNLOAD_DIR}/u-boot-digilent-${ZN_UBOOT_TAG}.tar.gz
ZN_UBOOT_URL=https://github.com/Digilent/u-boot-digilent/archive/${ZN_UBOOT_TAG}.tar.gz

# Download Bootloader
if [ ! -f "${ZN_UBOOT_TAR}" ]; then
    wget -t 0 -c -O ${ZN_UBOOT_TAR} ${ZN_UBOOT_URL}
fi

# Make sure directory is there
if [ ! -d "${ZN_UBOOT_DIR}" ]; then
    mkdir ${ZN_UBOOT_DIR}
fi

# Extract Bootloader
if [ "`ls -A ${ZN_UBOOT_DIR}`" = "" ]; then
    if [ -f "${ZN_UBOOT_TAR}" ]; then
        tar zxvf ${ZN_UBOOT_TAR} --strip-components=1 -C ${ZN_UBOOT_DIR}
    else
        error_exit "未找到U-Boot源码包!!!"
    fi
fi

# 2. The Linux kernel with Xilinx patches and drivers
print_info "Getting the Kernel Source Code..."
# ZN_KERNEL_TAG=digilent-v4.0
ZN_KERNEL_TAG=digilent-v4.4
ZN_KERNEL_TAR=${ZN_DOWNLOAD_DIR}/linux-digilent-${ZN_KERNEL_TAG}.tar.gz
ZN_KERNEL_URL=https://github.com/Digilent/linux-digilent/archive/${ZN_KERNEL_TAG}.tar.gz

# Download Linux Kernel
if [ ! -f "${ZN_KERNEL_TAR}" ]; then
    wget -t 0 -c -O ${ZN_KERNEL_TAR} ${ZN_KERNEL_URL}
fi

# Make sure directory is there
if [ ! -d "${ZN_KERNEL_DIR}" ]; then
    mkdir ${ZN_KERNEL_DIR}
fi

# Extract Linux Kernel
if [ "`ls -A ${ZN_KERNEL_DIR}`" = "" ]; then
    if [ -f "${ZN_KERNEL_TAR}" ]; then
        tar zxvf ${ZN_KERNEL_TAR} --strip-components=1 -C ${ZN_KERNEL_DIR}
    else
        error_exit "未找到kernel源码包!!!"
    fi
fi

# 3. Device Tree compiler (required to build U-Boot)
# https://git.kernel.org/pub/scm/utils/dtc/dtc.git
#
# git clone git://git.kernel.org/pub/scm/utils/dtc/dtc.git -b v1.4.1

# 4. Device Tree generator plugin for xsdk
print_info "Getting the Device Tree Generator Source Code..."
ZN_DTG_TAG=xilinx-v2015.4
# ZN_DTG_TAG=xilinx-v2016.2
# ZN_DTG_TAG=xilinx-v2017.1
ZN_DTG_TAR=${ZN_DOWNLOAD_DIR}/device-tree-xlnx-${ZN_DTG_TAG}.tar.gz
ZN_DTG_URL=https://github.com/Xilinx/device-tree-xlnx/archive/${ZN_DTG_TAG}.tar.gz

# Download Device Tree Generator
if [ ! -f "${ZN_DTG_TAR}" ]; then
    wget -t 0 -c -O ${ZN_DTG_TAR} ${ZN_DTG_URL}
fi

# Make sure directory is there
if [ ! -d "${ZN_DTG_DIR}" ]; then
    mkdir ${ZN_DTG_DIR}
fi

# Extract Device Tree generator
if [ "`ls -A ${ZN_DTG_DIR}`" = "" ]; then
    if [ -f "${ZN_DTG_TAR}" ]; then
        tar zxvf ${ZN_DTG_TAR} --strip-components=1 -C ${ZN_DTG_DIR}
    else
        error_exit "未找到Device Tree generator源码包!!!"
    fi
fi

# 5. The Linux File System
#
# 5.1. Using a BusyBox Ramdisk
# The BusyBox ramdisk is a very small file system that includes basic functionality
# and runs through RAM.  BusyBox is non-persistent, which means it will not save any
# changes you make during your operating session after you power down the ZedBoard.
#
# 5.1.1. Build Linux for Zynq-7000 AP SoC using Buildroot
# http://www.wiki.xilinx.com/Build+Linux+for+Zynq-7000+AP+SoC+using+Buildroot
print_info "Getting the Buildroot Source Code..."
#ZN_BUILDROOT_TAG=2017.02.9
#ZN_BUILDROOT_TAG=2017.11.2
ZN_BUILDROOT_TAG=2018.02
ZN_BUILDROOT_TAR=${ZN_DOWNLOAD_DIR}/buildroot-${ZN_BUILDROOT_TAG}.tar.gz
ZN_BUILDROOT_URL=https://buildroot.org/downloads/buildroot-${ZN_BUILDROOT_TAG}.tar.gz
#
# Download Buildroot
if [ ! -f "${ZN_BUILDROOT_TAR}" ]; then
    wget -t 0 -c -O ${ZN_BUILDROOT_TAR} ${ZN_BUILDROOT_URL}
fi

# Make sure directory is there
if [ ! -d "${ZN_BUILDROOT_DIR}" ]; then
    mkdir ${ZN_BUILDROOT_DIR}
fi

# Extract Buildroot
if [ ! -f "${ZN_BUILDROOT_DIR}/Makefile" ]; then
    if [ -f "${ZN_BUILDROOT_TAR}" ]; then
        tar zxvf ${ZN_BUILDROOT_TAR} --strip-components=1 -C ${ZN_BUILDROOT_DIR}
    else
        error_exit "未找到BUILDROOT源码包!!!"
    fi
fi

# 5.1.2. Xilinx Prebuilt RootFS
# This prebuilt ramdisk uses source code that Xilinx provides online.
# See the Xilinx materials at: http://wiki.xilinx.com/zynq-rootfs for a detailed description
# of the ramdisk and how to create a custom system.
print_info "Getting the Xilinx Prebuilt RootFS..."
ZN_RAMDISK_TAR=${ZN_DOWNLOAD_DIR}/ramdisk.image.gz
ZN_RAMDISK_URL=http://www.wiki.xilinx.com/file/view/arm_ramdisk.image.gz/419243558/arm_ramdisk.image.gz

# 开始下载RAMDISK包
if [ ! -f "${ZN_RAMDISK_TAR}" ]; then
    wget -t 0 -c -O ${ZN_RAMDISK_TAR} ${ZN_RAMDISK_URL}
fi

# 5.2. Using a Linaro File System
# The Linaro file system is a complete Linux distribution based on Ubuntu. Linaro executes
# from a separate partition on the SD card, and all changes made are written to memory. The
# utility of Linaro is that it will save files even after you power down and reboot the ZedBoard.
# http://www.wiki.xilinx.com/Ubuntu+on+Zynq


# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
