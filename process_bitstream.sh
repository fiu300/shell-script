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
    echo "Purpose: "
    echo "Version: V1.0"
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
#
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# Description
#
# This example design shows how to program the PL using the following Linux
# instructions and a raw binary bitstream.
#
# Once Linux is booted, mount the SD card and then create a device node for
# the Zynq devcfg block:
#
#     mknod /dev/xdevcfg c 259 0 > /dev/null
#
# Next, use the Linux "cat" command to stream the PL bitstream in the Zynq PL:
#
#     cat <path_to_storage_media>/<pl_bitstream_name>.bit.bin > /dev/xdevcfg
#
# The PL is now programmed.
#
# NOTE:
# In a later version of Linux Kernel the /dev/xdevcfg might be auto generated.
#
# When you encounter "mknod: /dev/xdevcfg: File exists" warning message after
# running the "mknod /dev/xdevcfg c 259 0 > /dev/null" command you can just run
# the next command.

#
# https://www.xilinx.com/support/answers/46913.html
#
# In order to use the Linux driver for devcfg to program the PL, the bitstream
# needs to be converted to a binary.
#
ZN_BIF_DIR=${ZN_TARGET_DIR}/all.bif

echo "all:"		    > ${ZN_BIF_DIR}
echo ""			    >>${ZN_BIF_DIR}
echo "{"		    >>${ZN_BIF_DIR}
echo ""			    >>${ZN_BIF_DIR}
echo "${ZN_TARGET_DIR}/system.bit"	>>${ZN_BIF_DIR}
echo ""			    >>${ZN_BIF_DIR}
echo "}"		    >>${ZN_BIF_DIR}

#
# Starting from 2014.1 Bootgen has an option called "process_bitstream" and it
# will generate the BIN file which can be used for PL to configure from PS via
# Devcfg.
#
bootgen -image ${ZN_BIF_DIR} -w -process_bitstream bin

# Output:
#
# The file system.bit.bin is generated in the current working directory.


# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
