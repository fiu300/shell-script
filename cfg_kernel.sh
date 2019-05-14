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
# The Linux Kernel Archives (https://www.kernel.org/)
# The Linux Kernel’s documentation (https://www.kernel.org/doc/html/latest/index.html)
# https://kernelnewbies.org/KernelBuild
# http://www.wiki.xilinx.com/Fetch+Sources
# http://www.wiki.xilinx.com/Build+Kernel
# http://www.wiki.xilinx.com/Build+Kernel#Zynq
# http://processors.wiki.ti.com/index.php/Linux_Kernel_Users_Guide
#
###############################################################################
# => Help and information
set -x

usage() {
    echo "Purpose: To configure the linux kernel"
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
# Note: What tools do I need? (https://kernelnewbies.org/KernelBuild)
#
# To build the Linux kernel from source, you need several tools:
# git, make, gcc, libssl-dev and (optionally) ctags, cscope, and/or ncurses-dev.
#
# The tool packages may be called something else in your Linux distribution, so
# you may need to search for the package. The ncurses-dev tools are used if you
# "make menuconfig" or "make nconfig".
#
# On Ubuntu, you can get these tools by running:
# sudo apt-get install libncurses5-dev gcc make git exuberant-ctags bc libssl-dev
#
# On Red Hat based systems like Fedora, Scientific Linux, and CentOS you can run:
# sudo yum install gcc make git ctags ncurses-devel openssl-devel
#
# And on SUSE based systems (like SLES and Leap), you can run:
# sudo zypper in git gcc ncurses-devel libopenssl-devel ctags cscope
#
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# => Make sure the source is there
if [ "`ls -A ${ZN_KERNEL_DIR}`" = "" ]; then
    error_exit "Can't find the source code of kernel !!!"
else
    cd ${ZN_KERNEL_DIR}
fi

# => Cleaning the Sources
# Prior to compiling the Linux kernel it is often a good idea to make sure that
# the kernel sources are clean and that there are no remnants left over from a
# previous build.
print_info "To delete all build products as well as the configuration ..."
make distclean
if [ $? -ne 0 ]; then
    error_exit "Failed to make distclean !!!"
fi

# => To configure the sources for the intended target.
print_info "Configure Linux kernel on the ${ZN_KERNEL_DIR} ..."
echo ${ZN_LINUX_KERNEL_DEFCONFIG}
make ${ZN_LINUX_KERNEL_DEFCONFIG}
if [ $? -ne 0 ]; then
    error_exit "Failed to make ${ZN_LINUX_KERNEL_DEFCONFIG} !!!"
fi

# => Prepare for compiling the source code
print_info "Prepare for compiling the source code ..."
make prepare scripts
if [ $? -ne 0 ]; then
    error_exit "Failed to make prepare scripts !!!"
fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"


set +x
