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
    echo "Purpose: To save Linux kernel config"
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
# To save Linux kernel config
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# => Make sure the source is there
if [ "`ls -A ${ZN_KERNEL_DIR}`" = "" ]; then
    error_exit "Can't find the source code of kernel !!!"
fi

# => To save kernel config use the command :
print_info "To save kernel config ..."
make -C ${ZN_KERNEL_DIR} savedefconfig
if [ $? != 0 ]; then
    error_exit "Failed to save defconfig !!!"
else
    cp ${ZN_KERNEL_DIR}/defconfig ${ZN_KERNEL_DIR}/arch/arm/configs/${ZN_LINUX_KERNEL_DEFCONFIG}
fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
