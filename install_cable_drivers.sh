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
    echo "Purpose: Install cable drivers"
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
# Install cable drivers
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# => Setting Zynq-7000 Development Environment Variables
if [ -f "${ZN_SCRIPTS_DIR}/export_xilinx_env.sh" ]; then
    source ${ZN_SCRIPTS_DIR}/export_xilinx_env.sh
else
    error_exit "Could not find file ${ZN_SCRIPTS_DIR}/export_xilinx_env.sh !!!"
fi

# You may have noticed that during installation (see step 5 above) the option
# to install cable drivers is grayed out, with a note to check guide UG973.
# If you own a Xilinx Platform USB cable you will need to manually install them:
if [ -d "${XILINX_VIVADO}" ]; then
    cd ${XILINX_VIVADO}/data/xicom/cable_drivers/lin64/install_script/install_drivers/
    sudo ./install_drivers
else
    error_exit "找不到Vivado设计套件！！！"
fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
