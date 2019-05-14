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
# http://www.wiki.xilinx.com/U-boot
# http://www.wiki.xilinx.com/U-Boot+Secondary+Program+Loader
# http://www.wiki.xilinx.com/Debug+U-boot
# http://www.wiki.xilinx.com/Build+U-Boot
# http://www.wiki.xilinx.com/Build+U-Boot#Zynq
# https://www.xilinx.com/video/hardware/debugging-u-boot-with-sdk.html
# https://github.com/Xilinx/u-boot-xlnx
#
###############################################################################
# => Help and information
usage() {
    echo "Purpose: To set the u-boot configuration automatically"
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
# To set the u-boot configuration automatically
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# => Make sure the source is there
echo "================="
echo ${ZN_UBOOT_DIR}
echo "================="
if [ "`ls -A ${ZN_UBOOT_DIR}`" = "" ]; then
    error_exit "Can't find the source code of u-boot !!!"
else
    cd ${ZN_UBOOT_DIR}
fi

# => Cleaning the Sources
print_info "To delete all build products as well as the configuration ..."
make distclean
if [ $? -ne 0 ]; then
    error_exit "Failed to make distclean !!!"
fi

# => To configure the sources for the intended target.
print_info "Configure u-boot on the ${ZN_UBOOT_DIR} ..."
echo "======== uboot defconfig =========="
echo ${ZN_UBOOOT_DEFCONFIG}
echo "=================================="
make ${ZN_UBOOOT_DEFCONFIG}
if [ $? -ne 0 ]; then
    error_exit "Failed to make ${ZN_UBOOOT_DEFCONFIG} !!!"
fi

# => Prepare for compiling the source code
print_info "Prepare for compiling the source code ..."
make tools
if [ $? -ne 0 ]; then
    error_exit "Failed to make tools !!!"
fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
