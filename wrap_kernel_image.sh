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
    echo "Purpose: Wrap the ramdisk image with the u-boot header"
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
# Wrap the ramdisk image with the u-boot header
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# http://www.wiki.xilinx.com/Build+and+Modify+a+Rootfs

# => Check File Type
print_info "Check File Type ..."
file ${ZN_OUTPUT_DIR}/ramdisk.image.gz
# ramdisk.image.gz: gzip compressed data, was "ramdisk.image", last modified: Tue Feb 28 13:41:42 2017, from Unix


# => Wrapping the image with a U-Boot header
print_info "Wrapping the image with a U-Boot header..."
# For Zynq AP SoC only, the ramdisk.image.gz needs to be wrapped with a U-Boot
# header in order for U-Boot to boot with it:
mkimage -A arm -T ramdisk -C gzip -d ${ZN_OUTPUT_DIR}/ramdisk.image.gz ${ZN_OUTPUT_DIR}/uramdisk.image.gz

# => Check File Type
print_info "Check File Type ..."
file ${ZN_OUTPUT_DIR}/uramdisk.image.gz
# uramdisk.image.gz: u-boot legacy uImage, , Linux/ARM, RAMDisk Image (gzip), 4815459 bytes, Fri May 30 01:52:10 2014,
# Load Address: 0x00000000, Entry Point: 0x00000000, Header CRC: 0x265787C1, Data CRC: 0x2CA30F4B

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
