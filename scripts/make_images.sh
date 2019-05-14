#!/bin/bash -e
#######################################################################################################################
# Copyright (C) 2014 - 2018 by osrc <www.osrc.cn>
#
# Embedded Linux Wiki (http://elinux.org/Main_Page)
#######################################################################################################################

#/ This script must be run with super-user privileges.
#/ Options:
#/   --help: Display this help message
usage() { grep '^#/' "$0" | cut -c4- ; exit 0 ; }
expr "$*" : ".*--help" > /dev/null && usage

# => Local functions
print_warning() { # 绿色字
	local msg="$1"
	printf "\033[32m[WARNING ] \033[0m";
	printf "$msg\n";
}
print_info() { # 黄色字
	local msg="$1"
	printf "\033[33m[INFO ] \033[0m";
	printf "$msg\n";
}
error_exit() { # 红色字
	local msg="$1"
	printf "\033[31m[ERROR ] \033[0m";
	printf "$msg\n";
	exit 1;
}

# => Normally this is called as 'source setup-env.sh'
if [ ! "${ZN_BASE_DIR}" ]; then
	if [ -f "setup_env.sh" ]; then
		source setup_env.sh
	else
		error_exit "请切换到scripts目录下，执行\"source setup-env.sh\"."
	fi
fi

# => Sometimes you may want to move the checking into the shell script itself. This is also possible.
# Add the following to the start of the script to only allow root or sudo access:
if [ `whoami` != root ]; then
	error_exit "Please run this script as root or using sudo"
fi

# => To make it so only non-root users should run the script do this:
#if [ `whoami` = root ]; then
#	error_exit "Please do not run this script as root or using sudo"
#fi

# => Filename of the running script.
script_name="$(basename ${BASH_SOURCE})"

# => Directory containing the running script.
script_dir="$(cd $(dirname ${BASH_SOURCE}) && pwd)"

# => Equivalent to $script_dir & "/" & $script_name
script_path=$(readlink -f "$0")

# => Redirect output to log from inside script
LOG_FILE="${ZN_LOGFILE_DIR}/${script_name}.log"
exec > >(tee ${LOG_FILE})
exec 2>&1

print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"
#######################################################################################################################
# => Setting Zynq-7000 Development Environment Variables
# http://www.wiki.xilinx.com/Install+Xilinx+Tools
#
# Xilinx Design Tools Version
# export ZN_XILINX_VERSION=2015.4
# Xilinx Tools
export XILINX=/mnt/workspace/toolchains/${ZN_XILINX_VERSION}
# XILINXD_LICENSE_FILE environment variable
# export XILINXD_LICENSE_FILE=<path-to-license>
# Vivado Design Suite
export XILINX_VIVADO=${XILINX}/Vivado/${ZN_XILINX_VERSION}
# The environment variables are written to settings[32|64].(c)sh
# To launch the Xilinx tools, first source the settings script:
source ${XILINX_VIVADO}/settings64.sh
# C-shell 64 bit environment...
# source ${XILINX_VIVADO}/settings64.csh
#
# https://forums.xilinx.com/t5/Installation-and-Licensing/librdi-common-not-found-executing-vivado/td-p/536991
# I've a "solution" to librdi_common* and actually some of the other missing libraries.
if grep "openSUSE Leap 42.1" /etc/issue >/dev/null 2>&1; then
	if [ -n "${LD_LIBRARY_PATH}" ]; then
		export LD_LIBRARY_PATH=${XILINX_VIVADO}/lib/lnx64.o:$LD_LIBRARY_PATH
	else
		export LD_LIBRARY_PATH=${XILINX_VIVADO}/lib/lnx64.o
	fi
fi


# => 制作qspi_image.mcs镜像
QSPI_IMAGE_MCS=${ZN_IMAGES_DIR}/recovery/qspi_image.mcs

# Create a new bif files...
QSPI_IMAGE_BIF=${ZN_TARGET_DIR}/qspi_image.bif
# 每次都重新生成qspi_image.bif文件，这样，就可以解决手动修改路径的问题。
echo "//arch = zynq; split = false; format = MCS"               > ${QSPI_IMAGE_BIF}
echo "the_ROM_image:"                                           >>${QSPI_IMAGE_BIF}
echo "{"                                                        >>${QSPI_IMAGE_BIF}
# The files we need are:
# 1. the first stage boot loader
echo "	[bootloader]${ZN_TARGET_DIR}/fsbl.elf"                  >>${QSPI_IMAGE_BIF}
# 2. FPGA bit stream
if [ -f "${ZN_TARGET_DIR}/system.bit" ]; then
	echo "	${ZN_TARGET_DIR}/system.bit"                    >>${QSPI_IMAGE_BIF}
fi
# 3. Das U-Boot boot loader
echo "	${ZN_TARGET_DIR}/u-boot.elf"                            >>${QSPI_IMAGE_BIF}
# 4. Linux kernel with modified header for U-Boot
echo "	[offset = 0x500000]${ZN_TARGET_DIR}/uImage.bin"         >>${QSPI_IMAGE_BIF}
# 5. Device tree blob
echo "	[offset = 0xA00000]${ZN_TARGET_DIR}/devicetree.dtb"     >>${QSPI_IMAGE_BIF}
# 6. Root filesystem
echo "	[offset = 0xA20000]${ZN_TARGET_DIR}/uramdisk.image.gz"  >>${QSPI_IMAGE_BIF}
echo "}"                                                        >>${QSPI_IMAGE_BIF}

#
bootgen -image ${QSPI_IMAGE_BIF} -o ${QSPI_IMAGE_MCS} -w on

# => 制作SD card镜像
# 清空旧文件
if [ "`ls -A ${ZN_IMAGES_DIR}`" != "" ]; then
	# 1. Generate the boot image BOOT.BIN
	rm -f ${ZN_IMAGES_DIR}/BOOT.bin
	# 2. uImage: Linux kernel with modified header for U-Boot
	rm -f ${ZN_IMAGES_DIR}/uImage
	# 3. Device tree blob
	rm -f ${ZN_IMAGES_DIR}/devicetree.dtb
	# 4. Root filesystem
	rm -f ${ZN_IMAGES_DIR}/uramdisk.image.gz
	# 5. uEnv.txt: Plain text file to set U-Boot environmental variables to boot from the SD card
	rm -f ${ZN_IMAGES_DIR}/uEnv.txt
fi

# 1. Generate the boot image BOOT.BIN
#
# This consists of the FSBL (first stage boot loader), the system.bit configuration bitstream,
# and the U-boot Linux boot-loader u-boot.elf.
#
# 1.1 Create a new bif files...
SD_IMAGE_BIF=${ZN_TARGET_DIR}/sd_image.bif
# 每次都重新生成sd_image.bif文件，这样，就可以解决手动修改路径的问题。
echo "//arch = zynq; split = false; format = BIN" > ${SD_IMAGE_BIF}
echo "the_ROM_image:"                             >>${SD_IMAGE_BIF}
echo "{"                                          >>${SD_IMAGE_BIF}
# 1.1.1 the first stage boot loader
echo "	[bootloader]${ZN_TARGET_DIR}/fsbl.elf"    >>${SD_IMAGE_BIF}
# 1.1.2 FPGA bit stream
if [ -f "${ZN_TARGET_DIR}/system.bit" ]; then
	echo "	${ZN_TARGET_DIR}/system.bit"      >>${SD_IMAGE_BIF}
fi
# 1.1.3 u-boot.elf: Das U-Boot boot loader
echo "	${ZN_TARGET_DIR}/u-boot.elf"              >>${SD_IMAGE_BIF}
echo "}"                                          >>${SD_IMAGE_BIF}
# 1.2
bootgen -image ${SD_IMAGE_BIF} -o ${ZN_IMAGES_DIR}/BOOT.bin -w on

# 2. uImage: Linux kernel with modified header for U-Boot
cp -a ${ZN_TARGET_DIR}/uImage              ${ZN_IMAGES_DIR}

# 3. Device tree blob
cp -a ${ZN_TARGET_DIR}/devicetree.dtb      ${ZN_IMAGES_DIR}

# 4. Root filesystem
cp -a ${ZN_TARGET_DIR}/uramdisk.image.gz   ${ZN_IMAGES_DIR}

# 5. uEnv.txt: Plain text file to set U-Boot environmental variables to boot from the SD card
# Plain text file to set U-Boot environmental variables to boot from the SD card
UENV_TXT=${ZN_IMAGES_DIR}/uEnv.txt
# 解决手动修改的问题。
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

echo "uenvcmd=run sdboot"                                      > ${UENV_TXT}
echo "sdboot=echo Copying Linux from SD to RAM... && \\"       >>${UENV_TXT}
# The files we need are:
# Linux kernel with modified header for U-Boot
echo "fatload mmc 0 0x4000000 \${kernel_image} && \\"          >>${UENV_TXT}
# Device tree blob
echo "fatload mmc 0 0x3A00000 \${devicetree_image} && \\"      >>${UENV_TXT}
# Root filesystem
# 若找到uramdisk.image.gz，则启动基于BusyBox的嵌入式Linux系统
echo "if fatload mmc 0 0x2000000 \${ramdisk_image}; \\"        >>${UENV_TXT}
echo "then bootm 0x4000000 0x2000000 0x3A00000; \\"            >>${UENV_TXT}
# 否则启动Linaro
echo "else bootm 0x4000000 - 0x3A00000; fi"                    >>${UENV_TXT}
echo ""                                                        >>${UENV_TXT}

#######################################################################################################################
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
