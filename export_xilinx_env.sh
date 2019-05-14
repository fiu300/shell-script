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
# Vivado HLx Editions QuickTake Video Tutorials
# https://www.xilinx.com/video/category/vivado-quicktake.html
#
# Setting Zynq-7000 Development Environment Variables
# http://www.wiki.xilinx.com/Install+Xilinx+Tools
#
# https://wiki.trenz-electronic.de/index.action
# http://www.fpgadeveloper.com/2016/11/tcl-automation-tips-for-vivado-xilinx-sdk.html
#
###############################################################################
# => Help and information
usage() {
    echo "Purpose: Setting Zynq-7000 Development Environment Variables"
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

# => Current Vivado/LabTool/SDK Version (Example:2015.4).
export VIVADO_VERSION="${VIVADO_VERSION:-2015.4}"
print_info "工具版本: ${VIVADO_VERSION}"

# => Set Xilinx installation path (Default: /opt/Xilinx/).
export XILINX="${XILINX:-/mnt/workspace/Xilinx}"
print_info "工具目录: ${XILINX}"

# => License information
# A. Xilinx default license locations
# B. XILINXD_LICENSE_FILE environment variable
export XILINXD_LICENSE_FILE="${ZN_SCRIPTS_DIR}/licenses"
# C. LM_LICENSE_FILE environment variable

# => Vivado Design Suite
export XILINX_VIVADO=${XILINX}/Vivado/${VIVADO_VERSION}

# => Xilinx Software Development Kit (XSDK):
# (only needed to build the FSBL).
export XILINX_SDK=${XILINX}/SDK/${VIVADO_VERSION}

# => High-Level Synthesis (HLS)
if [ "${VIVADO_VERSION}" == "2017.4" ]; then
    export XILINX_VIVADO_HLS=${XILINX_VIVADO}
else
    export XILINX_VIVADO_HLS=${XILINX}/Vivado_HLS/${VIVADO_VERSION}
fi

# => the SDSoC Development Environment
export XILINX_SDX=${XILINX}/SDx/${VIVADO_VERSION}

# => Docnav
export XILINX_DOCNAV=${XILINX}/DocNav

# => The Vivado Environment needs to be setup beforehand
###
# Note: There are two settings files available in the Vivado toolset:
# settings64.sh for use on 64-bit machines with bash;
# settings64.csh for use on 64-bit machines with C Shell.
###
if [ -d "${XILINX_VIVADO}" ]; then
    source ${XILINX_VIVADO}/settings64.sh
else
    print_error "找不到Vivado设计套件！！！"
    return 1;
fi

###
# Fixed: librdi_common* not found executing vivado
# https://forums.xilinx.com/t5/Installation-and-Licensing/librdi-common-not-found-executing-vivado/td-p/536991
###
if [ -n "${LD_LIBRARY_PATH}" ]; then
    export LD_LIBRARY_PATH=${XILINX_VIVADO}/lib/lnx64.o:$LD_LIBRARY_PATH
else
    export LD_LIBRARY_PATH=${XILINX_VIVADO}/lib/lnx64.o
fi

###
# Fixed: SDK (SWT issues in Eclipse)
###
# Try lsb_release, fallback with /etc/issue then uname command
distributions="(Debian|Ubuntu|RedHat|CentOS|openSUSE|SUSE)"
distribution=$(                                             \
    lsb_release -d 2>/dev/null | grep -Eo $distributions    \
    || grep -Eo $distributions /etc/issue 2>/dev/null       \
    || grep -Eo $distributions /etc/*-release 2>/dev/null   \
    || uname -s                                             \
    )

case ${distribution} in
    Ubuntu)
        export SWT_GTK3=0
        ;;
    *)
        ;;
esac

###
# Fixed: Docnav
###
if [ -n "${LD_LIBRARY_PATH}" ]; then
    export LD_LIBRARY_PATH=${XILINX_DOCNAV}:$LD_LIBRARY_PATH
else
    export LD_LIBRARY_PATH=${XILINX_DOCNAV}
fi
