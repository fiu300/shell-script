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
    echo "Purpose: Backup the Project"
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
# Backup the Project
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# =>
ZN_TOP_NAME="$(basename ${ZN_TOP_DIR})"
ZN_BACKUP_DIR="${ZN_TOP_DIR}/backup"
ZN_BACKUP_FILE="${ZN_BOARD_NAME}-${ZN_PROJECT_NAME}-V${VIVADO_VERSION}-$(date +%Y%m%d-%H%M%S)"

# => Invoke a second make in the output directory, passing relevant variables
# check that the output directory actually exists
mkdir -p ${ZN_BACKUP_DIR}

# =>
cd $(dirname ${ZN_TOP_DIR})

tar zcvf ${ZN_BACKUP_DIR}/${ZN_BACKUP_FILE}.tar.gz  --transform "s,^${ZN_TOP_NAME},${ZN_BACKUP_FILE}," \
    "${ZN_TOP_NAME}/boards/${ZN_BOARD_NAME}/${ZN_PROJECT_NAME}"                                        \
    "${ZN_TOP_NAME}/packages/buildroot"                                                                \
    "${ZN_TOP_NAME}/scripts"                                                                           \
    "${ZN_TOP_NAME}/sources"                                                                           \
    "${ZN_TOP_NAME}/tools/cross_compiler"

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
