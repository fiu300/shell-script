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
# 1. Build Device Tree Compiler (DTC)
# http://www.wiki.xilinx.com/Build+Device+Tree+Compiler+%28DTC%29
# 2. Build Device Tree Blob
# http://www.wiki.xilinx.com/Build+Device+Tree+Blob
#
###############################################################################

# => Help and information
usage() {
    echo "Purpose: Generate a Device Tree Source (.dts/.dtsi) files"
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
# Generate a Device Tree Source (.dts/.dtsi) files
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# 方法一: Generate a Device Tree Source (.dts/.dtsi) files from SDK

# 方法二: Generate a Device Tree Source (.dts/.dtsi) files on command line using HSM/HSI
#
# 1. Source Xilinx design tools
# 2. Run HSM or HSI (Vivado 2014.4 onwards)
#    hsm
# 3. Open HDF file
#    open_hw_design <design_name>.hdf
# 4. Set repository path (clone done in previous step in SDK) (On Windows use this format set_repo_path {C:\device-tree-xlnx})
#    set_repo_path <path to device-tree-xlnx repository>
# 5. Create SW design and setup CPU (for ZynqMP psu_cortexa53_0, for Zynq ps7_cortexa9_0, for Microblaze microblaze_0)
#    create_sw_design device-tree -os device_tree -proc ps7_cortexa9_0
# 6. Generate DTS/DTSI files to folder my_dts where output DTS/DTSI files will be generated
#    generate_target -dir my_dts
#
# Create a new tcl files...
HSI_DTS_FILE=${ZN_TARGET_DIR}/hsi_dts.tcl
# 每次都重新生成 hsi_dts.tcl 文件，这样，就可以解决手动修改路径的问题。
echo "open_hw_design ${ZN_SDK_PROJECT_DIR}/${ZN_BD_NAME}_wrapper.hdf"    > ${HSI_DTS_FILE}
echo "set_repo_path ${ZN_DTG_DIR}"                                       >>${HSI_DTS_FILE}
echo "create_sw_design device-tree -os device_tree -proc ps7_cortexa9_0" >>${HSI_DTS_FILE}
echo "generate_target -dir ${ZN_STANDALONE_DIR}/device_tree"             >>${HSI_DTS_FILE}
echo "exit"                                                              >>${HSI_DTS_FILE}
echo ""                                                                  >>${HSI_DTS_FILE}

hsi -mode tcl -source ${ZN_TARGET_DIR}/hsi_dts.tcl

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
