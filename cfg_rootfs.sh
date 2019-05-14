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
# https://buildroot.org/downloads/manual/manual.html
# http://www.wiki.xilinx.com/Build+and+Modify+a+Rootfs
# http://www.wiki.xilinx.com/Build+Linux+for+Zynq-7000+AP+SoC+using+Buildroot
#
###############################################################################
# => Help and information
usage() {
    echo "Purpose: To configure the buildroot"
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
# 1. Preparing to configure the buildroot
# The menuconfig tool requires the ncurses development headers to compile properly.
# sudo apt-get install libncurses5-dev
#
# 2. To configure the Buildroot
# Note: You should never use make -jN with Buildroot
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# => Try lsb_release, fallback with /etc/issue then uname command
distributions="(Debian|Ubuntu|RedHat|CentOS|openSUSE|SUSE)"
distribution=$(                                             \
    lsb_release -d 2>/dev/null | grep -Eo $distributions    \
    || grep -Eo $distributions /etc/issue 2>/dev/null       \
    || grep -Eo $distributions /etc/*-release 2>/dev/null   \
    || uname -s                                             \
    )

case ${distribution} in
    CentOS)
        # You have PERL_MM_OPT defined because Perl local::lib
        # is installed on your system. Please unset this variable
        # before starting Buildroot, otherwise the compilation of
        # Perl related packages will fail
        unset PERL_MM_OPT
        ;;
    *)
        ;;
esac

# => Make sure the source is there
if [ "`ls -A ${ZN_BUILDROOT_DIR}`" = "" ]; then
    error_exit "Can't find the source code of buildroot !!!"
else
    cd ${ZN_BUILDROOT_DIR}
fi

# => Cleaning the Sources
print_info "To delete all build products as well as the configuration ..."
make distclean
if [ $? -ne 0 ]; then
    error_exit "Failed to make distclean !!!"
fi

# => To configure the sources for the intended target.
print_info "Configure Buildroot on the ${ZN_BUILDROOT_DIR} ..."
make ${ZN_BUILDROOT_DEFCONFIG}
if [ $? -ne 0 ]; then
    error_exit "Failed to make ${ZN_BUILDROOT_DEFCONFIG} !!!"
fi

# => Download all sources needed for offline-build
print_info "Download all sources needed for offline-build ..."
make source
if [ $? -ne 0 ]; then
    error_exit "Failed to make source !!!"
fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
