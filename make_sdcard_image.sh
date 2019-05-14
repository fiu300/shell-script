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
    echo "Purpose: 制作基于Open Source Linux的SD卡镜像"
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
# 制作基于Open Source Linux的SD卡镜像
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# => 检查目标文件是否存在
# Overview of needed files
# For booting from SD Card following files are needed.
# 1. Boot.bin
#    The boot file includes:
#    FSBL        A file with the first stage boot loader
#    Bitfile     File with code for the Program Logic
#    U-boot      Boatloader file to load the Kernel with the device Tree
# 2. udev.txt
#    u-boot Parameter file
# 3. Kernel
#    uImage with the Linux kernel
# 4. Device Tree
#    dtb file with information about hardware system. The file is needed by the kernel
# 5. Linux distribution
#    A second partition with the Linux distribution file system
targets=(                          \
    "fsbl.elf"                     \
    "system.bit"                   \
    "u-boot.elf"                   \
    "uImage"                       \
    "devicetree.dtb"               \
    "ramdisk.image.gz"            \
    )

for target in "${targets[@]}"; do
    if [ ! -f "${ZN_TARGET_DIR}/${target}" ]; then
        print_info "找不到目标文件：${target}."
    fi
done

###############################################################################
# => 确定目标路径存在
###############################################################################
if [ ! -d "${ZN_SDCARD_IMG_DIR}" ]; then
    mkdir -p ${ZN_SDCARD_IMG_DIR}
fi

###############################################################################
# => 清空旧文件
###############################################################################
if [ "`ls -A ${ZN_SDCARD_IMG_DIR}`" != "" ]; then
    # 1. the boot image: BOOT.BIN
    rm -f ${ZN_SDCARD_IMG_DIR}/BOOT.bin
    # 2. Linux kernel with modified header for U-Boot
    rm -f ${ZN_SDCARD_IMG_DIR}/uImage
    # 3. Device tree blob
    rm -f ${ZN_SDCARD_IMG_DIR}/devicetree.dtb
    # 4. Root filesystem
    rm -f ${ZN_SDCARD_IMG_DIR}/uramdisk.image.gz

fi

# => 1. Generate the boot image BOOT.BIN
# This consists of the FSBL (first stage boot loader), the system.bit
# configuration bitstream, and the U-boot Linux boot-loader u-boot.elf.
# 1.1 Create a new bif files...
BIF_FILE=${ZN_TARGET_DIR}/sd_image.bif

# 每次都重新生成sd_image.bif文件，这样，就可以解决手动修改路径的问题。
echo "//arch = zynq; split = false; format = BIN" > ${BIF_FILE}
echo "the_ROM_image:"                             >>${BIF_FILE}
echo "{"                                          >>${BIF_FILE}
# 1.1.1 the first stage boot loader
echo "  [bootloader]${ZN_TARGET_DIR}/fsbl.elf"    >>${BIF_FILE}
# 1.1.2 FPGA bit stream
if [ -f "${ZN_TARGET_DIR}/system.bit" ]; then
    echo "  ${ZN_TARGET_DIR}/system.bit"          >>${BIF_FILE}
fi
# 1.1.3 u-boot.elf: Das U-Boot boot loader
echo "  ${ZN_TARGET_DIR}/u-boot.elf"              >>${BIF_FILE}
echo "}"                                          >>${BIF_FILE}

# 1.2 Setting Zynq-7000 Development Environment Variables
if [ -f "${ZN_SCRIPTS_DIR}/export_xilinx_env.sh" ]; then
    source ${ZN_SCRIPTS_DIR}/export_xilinx_env.sh
else
    error_exit "Could not find file ${ZN_SCRIPTS_DIR}/export_xilinx_env.sh !!!"
fi

# 1.3. Generate the boot image BOOT.BIN
bootgen -image ${BIF_FILE} -o ${ZN_SDCARD_IMG_DIR}/BOOT.bin -w on

echo "#################"
echo ${ZN_TARGET_DIR}
echo "#################"


# => 2. Linux kernel with modified header for U-Boot
cp ${ZN_TARGET_DIR}/uImage ${ZN_SDCARD_IMG_DIR}/uImage

# => 3. Device tree blob
cp ${ZN_TARGET_DIR}/devicetree.dtb ${ZN_SDCARD_IMG_DIR}/devicetree.dtb

# => 4. Root filesystem
cp ${ZN_TARGET_DIR}/uramdisk.image.gz ${ZN_SDCARD_IMG_DIR}/uramdisk.image.gz

# => 5. uEnv.txt: Plain text file to set U-Boot environmental variables to boot from the SD card
# Plain text file to set U-Boot environmental variables to boot from the SD card
UENV_TXT=${ZN_IMAGES_DIR}/uEnv.txt
# 解决手动修改的问题。

# 1111111111111
# echo "uenvcmd=run sdboot"                                      > ${UENV_TXT}
# echo "sdboot=echo Copying Linux from SD to RAM... && \\"       >>${UENV_TXT}
# # The files we need are:
# # Linux kernel with modified header for U-Boot
# echo "fatload mmc 0 0x3000000 \${kernel_image} && \\"          >>${UENV_TXT}
# # Device tree blob
# echo "fatload mmc 0 0x2A00000 \${devicetree_image} && \\"      >>${UENV_TXT}
# # Root filesystem
# # 若找到uramdisk.image.gz，则启动基于BusyBox的嵌入式Linux系统
# echo "if fatload mmc 0 0x2000000 \${ramdisk_image}; \\"        >>${UENV_TXT}
# echo "then bootm 0x3000000 0x2000000 0x2A00000; \\"            >>${UENV_TXT}
# # 否则启动Linaro
# echo "else bootm 0x3000000 - 0x2A00000; fi"                    >>${UENV_TXT}
# echo ""                                                        >>${UENV_TXT}

# 222222222222
# echo "uenvcmd=run sdboot"                                      > ${UENV_TXT}
# echo "sdboot=echo Copying Linux from SD to RAM... && \\"       >>${UENV_TXT}
# # The files we need are:
# # Linux kernel with modified header for U-Boot
# echo "fatload mmc 0 0x4000000 \${kernel_image} && \\"          >>${UENV_TXT}
# # Device tree blob
# echo "fatload mmc 0 0x3A00000 \${devicetree_image} && \\"      >>${UENV_TXT}
# # Root filesystem
# # 若找到uramdisk.image.gz，则启动基于BusyBox的嵌入式Linux系统
# echo "if fatload mmc 0 0x2000000 \${ramdisk_image}; \\"        >>${UENV_TXT}
# echo "then bootm 0x4000000 0x2000000 0x3A00000; \\"            >>${UENV_TXT}
# # 否则启动Linaro
# echo "else bootm 0x4000000 - 0x3A00000; fi"                    >>${UENV_TXT}
# echo ""                                                        >>${UENV_TXT}

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
