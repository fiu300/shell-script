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

#######################################################################################################################
#
# Flash Memory Programmer
#
# Usage:  program_flash   <FLASH OPTIONS>   <CABLE & DEVICE OPTIONS>
#
#  [FLASH OPTIONS]:
#     -f <image file>       : Image to be written onto the flash memory
#     -offset <address>     : Offset within the flash memory at which the image should be written
#     -no_erase             : Do not erase the flash memory before programming
#     -erase_only           : Only erases the flash as per size of the image file
#     -blank_check          : Check if the flash memory is erased
#     -verify               : Check if the flash memory is programmed correctly
#     -fsbl <fsbl file>     : For NAND & NOR flash types only (Zynq only)
#     -erase_sector <size>  : For flashes whose erase sector is other than 64KB (size in bytes)
#     -flash_type <type>    : Supported flash memory types
#                                 For Zynq Devices
#                                    1. qspi_single
#                                    2. qspi_dual_parallel
#                                    3. qspi_dual_stacked
#                                    4. nand_8
#                                    5. nand_16
#                                    6. nor
#                                 For Zynq MP Devices
#                                    1. qspi_single
#                                    2. qspi_dual_parallel
#                                    3. qspi_dual_stacked
#                                    4. nand_8
#                                 For Non-Zynq Devices
#                                    Please use the command line option -partlist to list all
#                                      the flash types
#     -partlist <bpi|spi> <micron|spansion> : List all the flash parts for Non-Zynq devices
#                                 List all flashes          - program_flash -partlist
#                                 List Micron BPI flashes   - program_flash -partlist bpi micron
#                                 List Spansion SPI flashes - program_flash -partlist spi spansion
#  [CABLE & DEVICE OPTIONS]:
#     -cable type xilinx_tcf esn <cable_esn> url <URL of the TCF agent>
#     -debugdevice deviceNr <jtag chain no>
#
#
#  EXAMPLES:
#   1. Zynq (QSPI Single)
#     program_flash -f BOOT.bin -flash_type qspi_single -blank_check \
    #        -verify -cable type xilinx_tcf url tcp:localhost:3121
#
#   2. Zynq (NOR)
#     program_flash -f BOOT.bin -fsbl fsbl.elf -flash_type nor -blank_check \
    #        -verify -cable type xilinx_tcf url tcp:localhost:3121
#
#   3. Non-Zynq (BPI)
#     program_flash -f hello.mcs -flash_type 28f00ap30t-bpi-x16 -blank_check \
    #        -verify -cable type xilinx_tcf url tcp:localhost:3121
#
#   4. Zynq MP (QSPI Dual Parallel)
#     program_flash -f BOOT.bin -fsbl fsbl.elf -flash_type qspi_dual_parallel -blank_check \
    #        -verify -cable type xilinx_tcf url tcp:localhost:3121
#######################################################################################################################
# 目标文件
QSPI_IMAGE_BIN=${ZN_QSPI_IMG_DIR}/qspi_image.bin
QSPI_IMAGE_MCS=${ZN_QSPI_IMG_DIR}/qspi_image.mcs

# 确定目标文件是否存在
if [ -f "${QSPI_IMAGE_MCS}" ]; then
    QSPI_IMAGE=${QSPI_IMAGE_MCS}
elif [ -f "${QSPI_IMAGE_BIN}" ]; then
    QSPI_IMAGE=${QSPI_IMAGE_BIN}
else
    error "未找到相关镜像..."
fi

# 烧录QSPI镜像
program_flash -f ${QSPI_IMAGE} -offset 0 -flash_type qspi_single -cable type xilinx_tcf url TCP:127.0.0.1:3121


# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
