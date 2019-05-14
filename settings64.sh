#!/bin/bash -e
###############################################################################
#
# Copyright (C) 2014 - 2018 by www.osrc.cn
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
# http://antmicro.com/
# http://www.wiki.xilinx.com
# https://github.com/kgugala/linux
# http://nanopi.org/NanoPi_Development.html
# http://ess-wiki.advantech.com.tw/view/Main_Page
#
###############################################################################
# => Help and information

set -x

usage() {
    echo "Purpose: To configure the developing environment automatically"
    echo "Note   : You have to run “source $(basename ${BASH_SOURCE})” every time once you open a new Terminal utility."
    echo "Version: V2018.03"
    echo "Usage  : $(basename ${BASH_SOURCE}) [option]"
    echo "options:"
    echo "--help: Display this help message"
    exit 0;
}
expr "$*" : ".*--help" > /dev/null && usage

# => Make sure the script is being source'd, not executed.  Otherwise,
# environment variables set here will not stick.
if [ ${BASH_SOURCE[0]} == "$0" ]; then
    echo "[Error] Please execute the script, such as : source `basename "$0"` !!!"
    exit 1;
fi

print_info "this is a test"
return 0
# => Prevent script from running twice.
if [ "$CROSS_COMPILE" != "" ];then
    print_error "It is already in cross compiling mode !!!"
    return 1;
fi

#------------------------------------------------------------------------------
# The basic directory
#------------------------------------------------------------------------------
# => Directory containing the running script (as required)
export ZN_SCRIPTS_DIR="$(cd $(dirname ${BASH_SOURCE}) && pwd)"
if [ "`ls -A ${ZN_SCRIPTS_DIR}`" = "" ]; then
    printf "Error: The scripts directory is empty!!!\n"
    return 1;
else
    # Adding the Directory to the Path
    export PATH=${ZN_SCRIPTS_DIR}:$PATH
    # => Import local function from common.sh
    if [ -f "${ZN_SCRIPTS_DIR}/common.sh" ]; then
        source ${ZN_SCRIPTS_DIR}/common.sh
    else
        printf "Error: Could not find file '${ZN_SCRIPTS_DIR}/common.sh'.\n"
        return 1;
    fi
fi

# => The Top Directory (as required)
export ZN_TOP_DIR="$(dirname ${ZN_SCRIPTS_DIR})"

# => The Boards Directory (as required)
export ZN_BOARDS_DIR="${ZN_TOP_DIR}/boards"

# => The Sources Directory (as required)
export ZN_SOURCES_DIR="${ZN_TOP_DIR}/sources"

# => The Documents Directory (as required)
export ZN_DOCUMENTS_DIR="${ZN_TOP_DIR}/documents"

# => The Packages (as required)
export ZN_DOWNLOAD_DIR="${ZN_TOP_DIR}/packages"

# => Host tools, cross compiler, utilities (as required)
export ZN_TOOLS_DIR=${ZN_TOP_DIR}/tools

# => Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${ZN_BOARDS_DIR} ${ZN_SOURCES_DIR} ${ZN_DOCUMENTS_DIR} ${ZN_DOWNLOAD_DIR} ${ZN_TOOLS_DIR}

#------------------------------------------------------------------------------
# Project basic settings
#------------------------------------------------------------------------------
# => The Board Name
export ZN_BOARD_NAME="mz7x"
print_info "板子名称: ${ZN_BOARD_NAME}"

# => The Board Directory
export ZN_BOARD_DIR="${ZN_BOARDS_DIR}/${ZN_BOARD_NAME}"
print_info "板子目录: ${ZN_BOARD_DIR}"

# => The Project Name
# export ZN_PROJECT_NAME="base"
# export ZN_PROJECT_NAME="button"
# export ZN_PROJECT_NAME="gpio"
# export ZN_PROJECT_NAME="gps"
# export ZN_PROJECT_NAME="i2c"
# export ZN_PROJECT_NAME="iio"
# export ZN_PROJECT_NAME="led"
# export ZN_PROJECT_NAME="rtc"
# export ZN_PROJECT_NAME="simple_dma_fifo"
# export ZN_PROJECT_NAME="simple_dma_loop"
export ZN_PROJECT_NAME="mylinux"
# export ZN_PROJECT_NAME="uart"
# export ZN_PROJECT_NAME="watchdog"
# export ZN_PROJECT_NAME="wifi"
print_info "项目名称: ${ZN_PROJECT_NAME}"

# => The Project Version
export ZN_PROJECT_VERSION=${ZN_PROJECT_VERSION:-1.0}
print_info "项目版本: ${ZN_PROJECT_VERSION}"

# => The Project Directory
export ZN_PROJECT_DIR="${ZN_BOARD_DIR}/${ZN_PROJECT_NAME}"
print_info "项目目录: ${ZN_PROJECT_DIR}"

# => The Build Output Directory
export ZN_OUTPUT_DIR=${ZN_PROJECT_DIR}/output
export ZN_TEMP_DIR=${ZN_OUTPUT_DIR}/temp
export ZN_TARGET_DIR=${ZN_OUTPUT_DIR}/target
export ZN_LOGFILE_DIR=${ZN_OUTPUT_DIR}/logfile
export ZN_ROOTFS_MOUNT_POINT=${ZN_OUTPUT_DIR}/rootfs
export ZN_SDCARD_MOUNT_POINT=${ZN_OUTPUT_DIR}/sdcard

# => The System Images Directory
export ZN_IMGS_DIR=${ZN_PROJECT_DIR}/images
export ZN_QSPI_IMG_DIR=${ZN_IMGS_DIR}/qspi_img
export ZN_EMMC_IMG_DIR=${ZN_IMGS_DIR}/emmc_img
export ZN_SDCARD_IMG_DIR=${ZN_IMGS_DIR}/sdcard_img
export ZN_LINARO_IMG_DIR=${ZN_IMGS_DIR}/linaro_img

# => Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${ZN_BOARD_DIR} ${ZN_PROJECT_DIR} ${ZN_OUTPUT_DIR} ${ZN_TEMP_DIR} \
    ${ZN_TARGET_DIR} ${ZN_LOGFILE_DIR} ${ZN_ROOTFS_MOUNT_POINT}            \
    ${ZN_SDCARD_MOUNT_POINT} ${ZN_QSPI_IMG_DIR} ${ZN_EMMC_IMG_DIR}         \
    ${ZN_SDCARD_IMG_DIR} ${ZN_LINARO_IMG_DIR}

#------------------------------------------------------------------------------
# System Hardware Design
# 1. Configure PS
# 2. Develop RTL/IP
# 3. Add/Integrate IP
# 4. Genrate Bitstream
# 5. Export to SDK
# 6. Standalone applications
#------------------------------------------------------------------------------
# => Current Vivado/LabTool/SDK Version (Example:2015.4).
#export VIVADO_VERSION="${VIVADO_VERSION:-2013.4}"
#export VIVADO_VERSION="${VIVADO_VERSION:-2014.4}"
#export VIVADO_VERSION="${VIVADO_VERSION:-2015.4}"
#export VIVADO_VERSION="${VIVADO_VERSION:-2016.4}"
 export VIVADO_VERSION="${VIVADO_VERSION:-2017.4}"
#export VIVADO_VERSION="${VIVADO_VERSION:-2018.1}"

# => Vivado工程名称（根据项目需求进行修改）
# export ZN_VIVADO_PROJECT_NAME="${ZN_PROJECT_NAME}"
export ZN_VIVADO_PROJECT_NAME="system"
print_info "工程名称: ${ZN_VIVADO_PROJECT_NAME}"

# => Vivado工程路径（根据项目需求进行修改）
export ZN_VIVADO_PROJECT_DIR="${ZN_PROJECT_DIR}/fpga/${ZN_VIVADO_PROJECT_NAME}"
print_info "工程路径: ${ZN_VIVADO_PROJECT_DIR}"

# => SDK工程路径（根据项目需求进行修改）
export ZN_SDK_PROJECT_DIR="${ZN_VIVADO_PROJECT_DIR}/${ZN_VIVADO_PROJECT_NAME}.sdk"

# => Block design name（根据项目需求进行修改）
export ZN_BD_NAME="system"
# => Vivado export a hardware description file for use whith the SDK
export ZN_HW_DESC_FILE_DIR="${ZN_SDK_PROJECT_DIR}/${ZN_BD_NAME}_wrapper_hw_platform_0"

# => Standalone Application
export ZN_STANDALONE_DIR=${ZN_PROJECT_DIR}/standalone

# => Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${ZN_VIVADO_PROJECT_DIR} ${ZN_STANDALONE_DIR}

#------------------------------------------------------------------------------
# Describe the toolchain for developing an embedded Linux operating system
#------------------------------------------------------------------------------
# => ARCH指明目标体系架构，即编译好的内核运行在什么平台上，如x86、arm或mips等
export ARCH=arm

# => 设置交叉编译工具
# 其中，CROSS_COMPILE指定使用的交叉编译器的前缀:
export ZN_TOOLCHAIN_PATH=${ZN_TOOLS_DIR}/cross_compiler
if [ -d "${ZN_TOOLCHAIN_PATH}/bin" ]; then
    # 指定交叉编译器
    export PATH=$PATH:${ZN_TOOLCHAIN_PATH}/bin
    ###
    # http://www.wiki.xilinx.com/Install+Xilinx+tools
    ###
    if which arm-linux-gnueabihf-gcc > /dev/null 2>&1 ; then
        # Zynq-7000 (Linaro - hard float)
        export ZN_TOOLCHAIN_PREFIX=arm-linux-gnueabihf
        export CROSS_COMPILE=${ZN_TOOLCHAIN_PREFIX}-
    elif which arm-xilinx-linux-gnueabi-gcc > /dev/null 2>&1 ; then
        # Zynq-7000 (CodeSourcery - soft floatb
        export ZN_TOOLCHAIN_PREFIX=arm-xilinx-linux-gnueabi
        export CROSS_COMPILE=${ZN_TOOLCHAIN_PREFIX}-
    else
        print_error "无法找到交叉编译器!!!"
        return 1;
    fi
else
    print_error "无法找到交叉编译器!!!"
    return 1;
fi

# => 并行编译
# Scale the maximum concurrency with the number of CPUs.
# http://www.verydemo.com/demo_c131_i121360.html
NUMBER_THREADS=`cat /proc/cpuinfo | grep "processor" | wc -l`
# Do not run with really big numbers unless you want your machine to be dog-slow!
if [ ${NUMBER_THREADS} -le 8 ] ; then
    export MAKE_JOBS="-j${NUMBER_THREADS}"
    export PARALLEL_MAKE="-j${NUMBER_THREADS}"
else
    export MAKE_JOBS="-j`expr ${NUMBER_THREADS} / 2`"
    export PARALLEL_MAKE="-j`expr ${NUMBER_THREADS} / 2`"
fi

#------------------------------------------------------------------------------
# System Software Development
#------------------------------------------------------------------------------
# => FSBL
# ==> Create the First Stage Boot Loader (FSBL) or U-BOOT spl bootloader
export ZN_FSBL_NAME=zynq_fsbl
export ZN_FSBL_DIR=${ZN_STANDALONE_DIR}/zynq_fsbl
# ==> Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${ZN_FSBL_DIR}

# => Device Tree
# ==> DTG (Device Tree Generator)
export ZN_DTG_DIR=${ZN_SOURCES_DIR}/dtg

# ==> DTS (Device Tree Source)
#export ZN_DTS_NAME="system.dts"
export ZN_DTS_NAME="system-top.dts"
export ZN_DTS_DIR=${ZN_PROJECT_DIR}/dts

# ==> DTB (Device Tree Blob)
export ZN_DTB_NAME="devicetree.dtb"
export ZN_DTB_DIR=${ZN_TARGET_DIR}

# ==> DTC (Device Tree Compiler) {{{
# When enabling verified boot you are going to build device tree files,
# therefore you also must install the device tree compiler.

# 方法一：单独下载dtc源码
# export ZN_DTC_DIR=${ZN_TOOLS_DIR}/dtc
# export PATH=${ZN_DTC_DIR}:$PATH

# 方法二：使用内核里的dtc（注：已经将该部分移到Linux小节进行配置）
# export ZN_DTC_DIR=${ZN_KERNEL_DIR}/scripts/dtc
# export PATH=${ZN_DTC_DIR}:$PATH

# 方法三： Ubuntu 12.04 LTS (Precise Pangolin) and later provide a version
# which is recent enough:
# sudo apt-get install device-tree-compiler
# }}}

# ==> Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${ZN_DTG_DIR} ${ZN_DTS_DIR}

# => Build U-Boot
# ==> ssbl : this folder stores all the U-Boot code.
export ZN_UBOOT_DIR=${ZN_SOURCES_DIR}/u-boot
# The uImage target of the Linux kernel compilation needs a recent mkimage tool
# which is actually built during U-Boot compilation as explained further below.
# Ensure that one is included in PATH:
export PATH=${ZN_UBOOT_DIR}/tools:$PATH

# ==> Configure the bootloader for the Zynq target
if [ "${ZN_BOARD_NAME}" == "zedboard" ]; then
    export ZN_UBOOOT_DEFCONFIG=zynq_zed_defconfig
elif [ "${ZN_BOARD_NAME}" == "zybo" ]; then
    export ZN_UBOOOT_DEFCONFIG=zynq_zybo_defconfig
elif [ "${ZN_BOARD_NAME}" == "mz7x" ]; then
    export ZN_UBOOOT_DEFCONFIG=zynq_mz7x_defconfig
else
    print_error "暂不支持该板子!!!"
    return 1;
fi

# ==> Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${ZN_UBOOT_DIR}

# => Build Linux
# ==> kernel : this folder stores the object files (not sources) of the kernel
# build process.
export ZN_KERNEL_DIR=${ZN_SOURCES_DIR}/kernel

# ==> modules : this folder stores the user kernel  modules. This is the place
# to create custom kernel modules.  Each module has to be in a subfolder of
# this one.
export ZN_MODULE_DIR=${ZN_SOURCES_DIR}/modules

# ==> 使用内核里的dtc
export ZN_DTC_DIR=${ZN_KERNEL_DIR}/scripts/dtc
export PATH=${ZN_DTC_DIR}:$PATH

# ==> Configure the Linux Kernel for the Zynq target
if [ "${ZN_BOARD_NAME}" == "zedboard" ]; then
    export ZN_LINUX_KERNEL_DEFCONFIG=xilinx_zed_defconfig
elif [ "${ZN_BOARD_NAME}" == "zybo" ]; then
    export ZN_LINUX_KERNEL_DEFCONFIG=xilinx_zybo_defconfig
elif [ "${ZN_BOARD_NAME}" == "mz7x" ]; then
    export ZN_LINUX_KERNEL_DEFCONFIG=xilinx_mz7x_defconfig
else
    print_error "暂不支持该板子!!!"
    return 1;
fi

# ==> Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${ZN_KERNEL_DIR} ${ZN_MODULE_DIR}

# => Create RamDisk (initial ramdisk)
# 方法一：使用Xilinx预编译的ramdisk
# http://www.wiki.xilinx.com/Build+and+Modify+a+Rootfs

# 方法二：使用Linaro等发行版

# 方法三：使用基于Busybox的根文件系统
# ==> Buildroot : Buildroot is a simple, efficient and easy-to-use tool to generate
# embedded Linux systems through cross-compilation.
export ZN_BUILDROOT_DIR=${ZN_SOURCES_DIR}/buildroot
# setup Buildroot download cache directory
export BR2_DL_DIR=${ZN_DOWNLOAD_DIR}/buildroot

# ==> Configure the buildroot for the Zynq target
if [ "${ZN_BOARD_NAME}" == "zedboard" ]; then
    export ZN_BUILDROOT_DEFCONFIG=zynq_zed_defconfig
elif [ "${ZN_BOARD_NAME}" == "zybo" ]; then
    export ZN_BUILDROOT_DEFCONFIG=zynq_zybo_defconfig
elif [ "${ZN_BOARD_NAME}" == "mz7x" ]; then
    export ZN_BUILDROOT_DEFCONFIG=zynq_mz7x_defconfig
else
    print_error "暂不支持该板子!!!"
    return 1;
fi

# => Ramdisk Constants
# 8M    16M    32M    64M    128M
# 8192  16384  32768  65536  131072
export ZN_RAMDISK_SIZE=65536
export ZN_BLOCK_SIZE=1024
export BLK_DEV_RAM_SIZE=${ZN_RAMDISK_SIZE}

# ==> Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${ZN_BUILDROOT_DIR} ${BR2_DL_DIR}

#------------------------------------------------------------------------------
# Application Development
# SDK: Build & Compile Application Code
#------------------------------------------------------------------------------
# => Linux Application
export ZN_APPS_DIR=${ZN_SOURCES_DIR}/applications

# => Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${ZN_APPS_DIR}

set +x
