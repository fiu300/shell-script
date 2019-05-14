#!/bin/bash -e
###############################################################################
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
    echo "Purpose: To configure the linux kernel"
    echo "Version: V2018.03"
    echo "Usage	 : $(basename ${BASH_SOURCE}) [option]"
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

# => hw_platform
ZYNQ_HW_PLATFORM_DIR=${ZN_VIVADO_PROJECT_DIR}/${ZN_VIVADO_PROJECT_NAME}.sdk/${ZN_VIVADO_PROJECT_NAME}_wrapper_hw_platform_0
# => bitstream
ZYNQ_BITSTREAM=${ZYNQ_HW_PLATFORM_DIR}/${ZN_VIVADO_PROJECT_NAME}_wrapper.bit
if [ ! -f "${ZYNQ_BITSTREAM}" ]; then
echo"$ZYNQ_HW_PLATFORM_DIR"
    error_exit "找不到system.bit"
 
fi
cp ${ZYNQ_BITSTREAM} ${ZN_TARGET_DIR}/system.bit

# => zynq_fsbl
ZYNQ_FSBL_DIR=${ZN_VIVADO_PROJECT_DIR}/${ZN_VIVADO_PROJECT_NAME}.sdk/zynq_fsbl
# 确定fsbl.elf文件是否存在
if [ -f "${ZYNQ_FSBL_DIR}/Release/zynq_fsbl.elf" ]; then
    cp ${ZYNQ_FSBL_DIR}/Release/zynq_fsbl.elf ${ZN_TARGET_DIR}/fsbl.elf
elif [ -f "${ZYNQ_FSBL_DIR}/Debug/zynq_fsbl.elf" ]; then
    cp ${ZYNQ_FSBL_DIR}/Debug/zynq_fsbl.elf ${ZN_TARGET_DIR}/fsbl.elf
else
echo"$ZYNQ_FSBL_DIR"
    error_exit "找不到fsbl.elf"
fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
