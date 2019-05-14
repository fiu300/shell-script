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

# => 确定fsbl.elf文件是否存在
# if [ ! -f "${ZN_TARGET_DIR}/fsbl.elf" ]; then
#     if [ -f "${ZN_FSBL_DIR}/Release/fsbl.elf" ]; then
#         cp ${ZN_FSBL_DIR}/Release/fsbl.elf ${ZN_TARGET_DIR}/fsbl.elf
#
#     elif [ -f "${ZN_FSBL_DIR}/Debug/fsbl.elf" ]; then
#         cp ${ZN_FSBL_DIR}/Debug/fsbl.elf ${ZN_TARGET_DIR}/fsbl.elf
#
#     else
#         error_exit "找不到fsbl.elf"
#     fi
# fi

# => 确定system_wrapper.bit文件是否存在
# if [ ! -f "${ZN_TARGET_DIR}/system.bit" ]; then
#     if [ -f "${ZN_BIT_DIR}/system_wrapper.bit" ]; then
#         cp ${ZN_BIT_DIR}/system_wrapper.bit ${ZN_TARGET_DIR}/system.bit
#     else
#         error_exit "找不到system_wrapper.bit"
#     fi
# fi


# => 确定u-boot.elf文件是否存在
if [ ! -f "${ZN_TARGET_DIR}/u-boot.elf" ]; then
    error_exit "找不到u-boot.elf"
fi

# => 确定uImage文件是否存在
if [ ! -f "${ZN_TARGET_DIR}/uImage" ]; then
    error_exit "找不到uImage"
fi

# => 确定devicetree.dtb文件是否存在
if [ ! -f "${ZN_TARGET_DIR}/devicetree.dtb" ]; then
    error_exit "找不到devicetree.dtb"
fi

# => 确定uramdisk.image.gz文件是否存在
if [ ! -f "${ZN_TARGET_DIR}/uramdisk.image.gz" ]; then
    error_exit "找不到uramdisk.image.gz"
fi

# => 确定目标路径存在
if [ ! -d "${ZN_QSPI_IMG_DIR}" ]; then
    mkdir -p ${ZN_QSPI_IMG_DIR}
fi

#######################################################################################################################
# Create a new bif files...
#######################################################################################################################
BIF_FILE=${ZN_TARGET_DIR}/qspi_image.bif
#
# 每次都重新生成qspi_image.bif文件，这样，就可以解决手动修改路径的问题。
echo "//arch = zynq; split = false; format = BIN"                 > ${BIF_FILE}
echo "the_ROM_image:"                                             >>${BIF_FILE}
echo "{"                                                          >>${BIF_FILE}
# The files we need are:
# 1. the first stage boot loader
echo "	[bootloader]${ZN_TARGET_DIR}/fsbl.elf"                    >>${BIF_FILE}
# 2. FPGA bit stream
if [ -f "${ZN_TARGET_DIR}/system.bit" ]; then
    echo "	${ZN_TARGET_DIR}/system.bit"                      >>${BIF_FILE}
fi
# 3. Das U-Boot boot loader
echo "	${ZN_TARGET_DIR}/u-boot.elf"                              >>${BIF_FILE}
# 4. Linux kernel with modified header for U-Boot
echo "	[offset = 0x500000]${ZN_TARGET_DIR}/uImage.bin"           >>${BIF_FILE}
# 5. Device tree blob
echo "	[offset = 0xA00000]${ZN_TARGET_DIR}/devicetree.dtb"       >>${BIF_FILE}
# 6. Root filesystem
echo "	[offset = 0xA20000]${ZN_TARGET_DIR}/uramdisk.image.gz"    >>${BIF_FILE}
echo "}"                                                          >>${BIF_FILE}

#######################################################################################################################
#
#######################################################################################################################
QSPI_IMAGE_BIN=${ZN_QSPI_IMG_DIR}/qspi_image.bin
QSPI_IMAGE_MCS=${ZN_QSPI_IMG_DIR}/qspi_image.mcs

QSPI_IMAGE=${QSPI_IMAGE_BIN}

bootgen -image ${BIF_FILE} -o ${QSPI_IMAGE} -w on

# cd ${ZN_TARGET_DIR}
# bootgen -image ${BIF_FILE} -o ${QSPI_IMAGE} -w on -split bin
# cd -


# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
