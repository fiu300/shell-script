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
#
###############################################################################
# => Help and information
usage() {
    echo "Purpose: Using GNU Screen"
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
# Using GNU Screen
#
# Note:-You can also use minicom, but screen is much easier to use!  Also
# in most cases the virtual USB serial port is ttyUSB0.
#
# https://builder.timesys.com/docs/gsg/zc706
# The Zynq uses a USB serial debug port to communicate with the host machine. The
# commands discussed in this section are meant to be performed by a privileged
# user account. This requires the root login or prepending each command with sudo.
#
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

if type screen > /dev/null 2>&1; then
    #
    # To quickly connect to a board using Gnu Screen, execute the following:
    #
    if [ "${ZN_BOARD_NAME}" == "zedboard" ]; then
        if [ -c /dev/ttyACM0 ]; then
            sudo screen /dev/ttyACM0 115200 8n1
        else
            error_exit "the /dev/ttyACM0 is not exist"
        fi
    elif [ "${ZN_BOARD_NAME}" == "zybo" ]; then
        if [ -c /dev/ttyUSB1 ]; then
            sudo screen /dev/ttyUSB1 115200 8n1
        else
            error_exit "the /dev/ttyUSB1 is not exist"
        fi
    else
        if [ -c /dev/ttyUSB0 ]; then
            sudo screen /dev/ttyUSB0 115200 8n1
        else
            error_exit "the /dev/ttyUSB0 is not exist"
        fi
    fi
    #
    # For more information about using screen, please consult the man page, or view
    # the manual online at http://www.gnu.org/software/screen/manual/screen.html

fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
