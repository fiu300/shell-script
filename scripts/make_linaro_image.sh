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
    echo "Purpose: 制作 linaro 镜像"
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
# 制作 linaro 镜像
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# => 检查目标文件是否存在
if [ "${ZN_BOARD_NAME}" == "mz7x" ]; then

  targets=(                        \
    "fsbl.elf"                     \
    "u-boot.elf"                   \
    "fit.itb"                      \
    )

else

  targets=(                        \
    "fsbl.elf"                     \
    "u-boot.elf"                   \
    "uImage"                       \
    "devicetree.dtb"               \
    "uramdisk.image.gz"            \
    )

fi

for target in "${targets[@]}"; do
  if [ ! -f "${ZN_TARGET_DIR}/${target}" ]; then
    print_info "找不到目标文件：${target}."
  fi
done

###############################################################################
# => 确定目标路径存在
###############################################################################
if [ ! -d "${ZN_LIMG_DIR}" ]; then
  mkdir -p ${ZN_LIMG_DIR}
fi

###############################################################################
# => 清空旧文件
###############################################################################
if [ "`ls -A ${ZN_LIMG_DIR}`" != "" ]; then
  if [ "${ZN_BOARD_NAME}" == "mz7x" ]; then

    # 1. the boot image: BOOT.BIN
    rm -f ${ZN_LIMG_DIR}/BOOT.bin
    # 2. the FIT image: fit.itb
    rm -f ${ZN_LIMG_DIR}/fit.itb

  else

    # 1. the boot image: BOOT.BIN
    rm -f ${ZN_LIMG_DIR}/BOOT.bin
    # 2. Linux kernel with modified header for U-Boot
    rm -f ${ZN_LIMG_DIR}/uImage
    # 3. Device tree blob
    rm -f ${ZN_LIMG_DIR}/devicetree.dtb
    # 4. Root filesystem
    rm -f ${ZN_LIMG_DIR}/uramdisk.image.gz

  fi
fi

# => 1. Generate the boot image BOOT.BIN
# This consists of the FSBL (first stage boot loader), the system.bit
# configuration bitstream, and the U-boot Linux boot-loader u-boot.elf.
# 1.1 Create a new bif files...
BIF_FILE=${ZN_TARGET_DIR}/linaro_image.bif
#
# 每次都重新生成sd_image.bif文件，这样，就可以解决手动修改路径的问题。
echo "//arch = zynq; split = false; format = BIN" > ${BIF_FILE}
echo "the_ROM_image:"                             >>${BIF_FILE}
echo "{"                                          >>${BIF_FILE}
# 1.1.1 the first stage boot loader
echo "  [bootloader]${ZN_TARGET_DIR}/fsbl.elf"    >>${BIF_FILE}
# 1.1.2 FPGA bit stream
if [ -f "${ZN_TARGET_DIR}/system.bit" ]; then
  echo "  ${ZN_TARGET_DIR}/system.bit"            >>${BIF_FILE}
fi
# 1.1.3 u-boot.elf: Das U-Boot boot loader
echo "  ${ZN_TARGET_DIR}/u-boot.elf"              >>${BIF_FILE}
echo "}"                                          >>${BIF_FILE}
# 1.2
bootgen -image ${BIF_FILE} -o ${ZN_LIMG_DIR}/BOOT.bin -w on

# =>
if [ "${ZN_BOARD_NAME}" == "mz7x" ]; then

  # the FIT image: fit.itb
  cp ${ZN_TARGET_DIR}/fit.itb ${ZN_LIMG_DIR}/fit.itb

else

  # Linux kernel with modified header for U-Boot
  cp ${ZN_TARGET_DIR}/uImage ${ZN_LIMG_DIR}/uImage
  # Device tree blob
  cp ${ZN_TARGET_DIR}/devicetree.dtb ${ZN_LIMG_DIR}/devicetree.dtb
  # Root filesystem
  cp ${ZN_TARGET_DIR}/uramdisk.image.gz ${ZN_LIMG_DIR}/uramdisk.image.gz

fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
