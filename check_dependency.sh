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
# Setting Zynq-7000 Development Environment Variables
# http://www.wiki.xilinx.com/Install+Xilinx+Tools
#
# How do I find out which libraries are required to run Vivado tools in Linux?
# https://www.xilinx.com/support/answers/66184.html
#
# Vivado Design Hub - Installation and Licensing
# https://www.xilinx.com/support/documentation-navigation/design-hubs/dh0013-vivado-installation-and-licensing-hub.html
#
###############################################################################
# => Help and information
usage() {
    echo "Purpose: 检查Vivado开发套件是否缺少依赖包"
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
# 检查Vivado开发套件是否缺少依赖包
###############################################################################
# => The beginning
#print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# To check which required library or libraries are missing on a Linux system,
# you can use the ldd command recursively.  A Perl script that handles the
# recursive ldd search, named ldd-recursive.pl is available at:
# http://sourceforge.net/projects/recursive-ldd/
if [ ! -f "${script_dir}/ldd-recursive.pl" ]; then
    error_exit "Can not find Perl script !!!"
fi

# To use the script:
# 1) Perl must be installed on your system.
if [ "$(command -v perl)" = "" ]; then
    error_exit "Can not find Perl executable !!!"
fi

# 2) For valid switches and syntax:
#    perl ldd-recursive.pl

# 3) The Vivado Environment needs to be setup beforehand
if [ -f "${ZN_SCRIPTS_DIR}/export_xilinx_env.sh" ]; then
    source ${ZN_SCRIPTS_DIR}/export_xilinx_env.sh
else
    error_exit "Could not find file '${ZN_SCRIPTS_DIR}/export_xilinx_env.sh' !!!"
fi


# 4) Execute the script as follows to get a unique list (no duplicates) of the
# required libraries needed:

# => Vivado Design Suite
if [ -d "${XILINX_VIVADO}" ]; then
    print_info "Vivado requires libraries:"
    perl ${script_dir}/ldd-recursive.pl ${XILINX_VIVADO}/bin/unwrapped/lnx64.o/vivado -uniq
fi

# => Xilinx Software Development Kit (XSDK):
# (only needed to build the FSBL).
if [ -d "${XILINX_SDK}" ]; then
    print_info "SDK requires libraries:"

    if [ "${VIVADO_VERSION}" == "2013.4" ]; then
        perl ${script_dir}/ldd-recursive.pl ${XILINX_SDK}/bin/lin64/unwrapped/xsdk -uniq
    else
        perl ${script_dir}/ldd-recursive.pl ${XILINX_SDK}/bin/unwrapped/lnx64.o/rdi_xsdk -uniq
    fi
fi

# => High-Level Synthesis (HLS)
if [ -d "${XILINX_VIVADO_HLS}" ]; then
    print_info "Vivado HLS requires libraries:"
    perl ${script_dir}/ldd-recursive.pl ${XILINX_VIVADO_HLS}/bin/unwrapped/lnx64.o/vivado_hls -uniq
fi

# => DocNav
if [ -d "${XILINX_DOCNAV}" ]; then
    # Note: DocNav is a 32-bit executable and requires the libraries listed above to run.
    print_info "DocNav requires libraries:"
    perl ${script_dir}/ldd-recursive.pl ${XILINX_DOCNAV}/docnav -uniq
fi

# NOTE: This script was not created or supported by Xilinx and therefore any
# issues or questions related to running the script should not be directed to
# Xilinx.

# => The end
#print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
