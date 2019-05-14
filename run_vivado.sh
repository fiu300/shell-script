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
# Vivado 2016.4 on Ubuntu 16.04 LTS - "awk: symbol lookup error: awk: undefined symbol: mpfr_z_sub" error is back again
# https://forums.xilinx.com/t5/Installation-and-Licensing/Vivado-2016-4-on-Ubuntu-16-04-LTS-quot-awk-symbol-lookup-error/m-p/756779#M17778
#
###############################################################################
# => Help and information
usage() {
    echo "Purpose: Starting Vivado"
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
# Starting Vivado
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# Embedded Linux Wiki (http://elinux.org/Main_Page)
# The Linux Kernel Archives (https://www.kernel.org/)
# The Linux Kernel’s documentation (https://www.kernel.org/doc/html/latest/index.html)
# Trenz Electronic Documentation (https://wiki.trenz-electronic.de/index.action)

# => Setting Zynq-7000 Development Environment Variables
if [ -f "${ZN_SCRIPTS_DIR}/export_xilinx_env.sh" ]; then
    source ${ZN_SCRIPTS_DIR}/export_xilinx_env.sh
else
    error_exit "Could not find file ${ZN_SCRIPTS_DIR}/export_xilinx_env.sh !!!"
fi


# => 打开vivado开发环境
# This will ensure that the .jou and .log files are placed in the project directory.
cd ${ZN_VIVADO_PROJECT_DIR}
# open the Vivado IDE
if [ -f "${ZN_VIVADO_PROJECT_DIR}/${ZN_VIVADO_PROJECT_NAME}.xpr" ]; then
    vivado ${ZN_VIVADO_PROJECT_DIR}/${ZN_VIVADO_PROJECT_NAME}.xpr > /dev/null 2>&1 &

elif [ -f "${ZN_VIVADO_PROJECT_DIR}/create_project.tcl" ]; then
    vivado -source ${ZN_VIVADO_PROJECT_DIR}/create_project.tcl > /dev/null 2>&1 &

else
    vivado > /dev/null 2>&1 &
fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
