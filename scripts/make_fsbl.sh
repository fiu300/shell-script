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
# http://www.wiki.xilinx.com/FSBL
# http://www.wiki.xilinx.com/Build+FSBL
#
###############################################################################

# => Help and information
usage() {
    echo "Purpose: Generate and Build the First Stage Boot Loader (FSBL)"
    echo "Version: V2018.01"
    echo "Usage  : $script_name [option]"
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
        printf "Error: Could not find file '${script_dir}/settings64.sh'.\n"
        return 1
    fi
else
    # => Import local function from common.sh
    if [ -f "${script_dir}/common.sh" ]; then
        source ${script_dir}/common.sh
    else
        printf "Error: Could not find file '${script_dir}/common.sh'.\n"
        return 1;
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
# Generate and Build the First Stage Boot Loader (FSBL)
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# 方法一: Using SDK
## https://www.xilinx.com/html_docs/xilinx2017_4/SDK_Doc/SDK_tasks/task_creatinganewzynqfsblapplicationproject.html
#ZYNQ_FSBL_DIR=${ZN_VIVADO_PROJECT_DIR}/${ZN_VIVADO_PROJECT_NAME}.sdk/zynq_fsbl
## 确定fsbl.elf文件是否存在
#if [ -f "${ZYNQ_FSBL_DIR}/Release/zynq_fsbl.elf" ]; then
#    cp ${ZYNQ_FSBL_DIR}/Release/zynq_fsbl.elf ${ZN_TARGET_DIR}/fsbl.elf
#elif [ -f "${ZYNQ_FSBL_DIR}/Debug/zynq_fsbl.elf" ]; then
#    cp ${ZYNQ_FSBL_DIR}/Debug/zynq_fsbl.elf ${ZN_TARGET_DIR}/fsbl.elf
#else
#    error_exit "找不到fsbl.elf"
#fi

# 方法二: Using HSI
# https://forums.xilinx.com/t5/Vivado-TCL-Community/export-hwdef-sysdef-for-FSBL-and-devicetree-WITHOUT-USING-ANY/td-p/794843

# Create a new tcl files...
TCL_FILE=${ZN_TARGET_DIR}/hsi_fsbl.tcl
# 每次都重新生成 hsi_dts.tcl 文件，这样，就可以解决手动修改路径的问题。
echo "set hwdsgn [open_hw_design ${ZN_SDK_PROJECT_DIR}/${ZN_BD_NAME}_wrapper.hdf]"                                            > ${TCL_FILE}
echo "generate_app -hw \$hwdsgn -os standalone -proc ps7_cortexa9_0 -app zynq_fsbl -compile -sw zynq_fsbl -dir ${ZN_FSBL_DIR}" >>${TCL_FILE}
echo "exit"                                                                                                                   >>${TCL_FILE}
echo ""                                                                                                                       >>${TCL_FILE}

hsi -mode tcl -source ${ZN_TARGET_DIR}/hsi_fsbl.tcl

if [ -f "${ZN_FSBL_DIR}/executable.elf" ]; then
    mv ${ZN_FSBL_DIR}/executable.elf ${ZN_TARGET_DIR}/fsbl.elf
fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
