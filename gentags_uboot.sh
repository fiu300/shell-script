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
    echo "Purpose: Creating index database of the u-boot"
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
# Creating index database of the u-boot
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# => Make sure the source is there
if [ "`ls -A ${ZN_UBOOT_DIR}`" = "" ]; then
    error_exit "Can't find the source code of u-boot !!!"
else
    cd ${ZN_UBOOT_DIR}
fi

# => Installing indexing tools
# To navigate kernel code I would advise cscope and ctags tools. To install them run next command:
# sudo aptitude install cscope exuberant-ctags

# => Creating index database
which ctags &> /dev/null && echo "Generate tags file for editors" && make tags

which cscope &> /dev/null && echo "Generate cscope index" && make cscope

# etags         - Generate etags file for editors

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
