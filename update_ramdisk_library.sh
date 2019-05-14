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
    echo "Purpose: "
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
#
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# Zynq Root File System Creation
# http://xilinx.wikidot.com/zynq-rootfs

# 确定ramdisk.image.gz文件是否存在
if [ ! -f "${ZN_OUTPUT_DIR}/ramdisk.image.gz" ]; then
    if [ ! -f "${ZN_DOWNLOAD_DIR}/ramdisk.image.gz" ]; then
        error "找不到ramdisk.image.gz"
    else
        cp ${ZN_DOWNLOAD_DIR}/ramdisk.image.gz ${ZN_OUTPUT_DIR}/
    fi
fi
# 预处理。。。
gunzip ${ZN_OUTPUT_DIR}/ramdisk.image.gz
chmod u+rwx ${ZN_OUTPUT_DIR}/ramdisk.image
mount -o loop ${ZN_OUTPUT_DIR}/ramdisk.image ${ZN_ROOTFS_MOUNT_POINT}
rm -r ${ZN_ROOTFS_MOUNT_POINT}/lib/*

# Toolchain Library
# The Xilinx ARM tool-chain includes a pre-built standard C library along with some helper applications like gdb-server.
#
# 1. Copy in the supplied libraries:
# cp -r ${ZN_CROSS_COMPILE_PATH}/arm-xilinx-linux-gnueabi/libc/lib/* ${ZN_ROOTFS_MOUNT_POINT}/lib
cp -r ${ZN_TOOLS_DIR}/cross_compiler/arm-xilinx-linux-gnueabi/libc/lib/* ${ZN_ROOTFS_MOUNT_POINT}/lib

# 2. Strip the libraries of debug symbols:
${CROSS_COMPILE}strip ${ZN_ROOTFS_MOUNT_POINT}/lib/*

# 3. Copy in the supplied tools in libc/sbin and libc/usr/bin
# cp -r ${ZN_CROSS_COMPILE_PATH}/arm-xilinx-linux-gnueabi/libc/sbin/*    ${ZN_ROOTFS_MOUNT_POINT}/sbin/
# cp -r ${ZN_CROSS_COMPILE_PATH}/arm-xilinx-linux-gnueabi/libc/usr/bin/* ${ZN_ROOTFS_MOUNT_POINT}/usr/bin/

# 后处理。。。
umount ${ZN_ROOTFS_MOUNT_POINT}
gzip ${ZN_OUTPUT_DIR}/ramdisk.image
mkimage -A arm -T ramdisk -C gzip -d ${ZN_OUTPUT_DIR}/ramdisk.image.gz \
    ${ZN_TARGET_DIR}/uramdisk.image.gz


# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
