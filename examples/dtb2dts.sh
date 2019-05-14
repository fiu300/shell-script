#!/bin/bash -e
###############################################################################
#
# Copyright (C) 2014 - 2018 by Yujiang Lin <linyujiang@hotmail.com>
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

# Build Device Tree Compiler (DTC)
# 1. Fetch Sources
# git clone git://git.kernel.org/pub/scm/utils/dtc/dtc.git -b v1.4.1

# 2. Build DTC
# All commands have to be executed in your DTC source directory. There is a
# single dtc binary suitable for all architectures. There is not a need to build
# separate dtc binaries to support MicroBlaze and ARM.

# make

# 3. After the build process completes the dtc binary is created within the
# current directory. It is neccessary to make the path to the dtc binary
# accessible to tools (eg, the U-Boot build process). To make dtc available in
# other steps, it is recommended to add the tools directory to your $PATH
# variable.

# export PATH=`pwd`:$PATH

# 4. DTC may also be used to convert a DTB back into a DTS:

# ./scripts/dtc/dtc -I dtb -O dts -o <devicetree name>.dts <devicetree name>.dtb

${ZN_KERNEL_DIR}/scripts/dtc/dtc -I dtb -O dts -o ${ZN_DTS_DIR}/${ZN_DTS_NAME} ${ZN_DTB_DIR}/${ZN_DTB_NAME}
if [ $? -eq 0 ]; then
    print_info "The Device Tree - Build OK!!!"
else
    error_exit "The Device Tree - Build Failed!!!"
fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
