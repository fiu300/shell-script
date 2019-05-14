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
# http://www.wiki.xilinx.com/U-boot
# http://www.wiki.xilinx.com/U-Boot+Secondary+Program+Loader
# http://www.wiki.xilinx.com/Debug+U-boot
# http://www.wiki.xilinx.com/Build+U-Boot
# http://www.wiki.xilinx.com/Build+U-Boot#Zynq
# https://www.xilinx.com/video/hardware/debugging-u-boot-with-sdk.html
# https://github.com/Xilinx/u-boot-xlnx
#
# => U-boot Release Notes
# http://www.wiki.xilinx.com/2016.4+U-boot+Release+Notes
# http://www.wiki.xilinx.com/2017.1+u-boot+Release+Notes
#
# => U-Boot 14.3 (and newer releases) Specific Details
# U-Boot is now by default expecting a uImage Linux kernel image and a ramdisk
# that is also wrapped with the mkimage utility. It is using the bootm command
# by default now which also passes the address of the device tree to the Linux
# kernel. The Linux build process will build a uImage when the uImage target is
# specified on the make command line.
#
# => Mkimage Utility:
# The mkimage utility is part of U-Boot and is placed in the u-boot/tools
# directory during the build process. It is used to prepend a header onto the
# specified image such that U-Boot can verify an image was loaded into memory
# correctly.
#
# => Bootm Command Details
# The bootm command has the following format:
#
# bootm <Linux uImage address> <mkimage wrapped ramdisk address> <device tree (dtb) address>
#
# The following U-Boot commands illustrate loading the Linux kernel uImage, a
# mkimage wrapped ramdisk, and a device tree into memory from the SD card and
# then booting the Linux kernel.
#
# u-boot> fatload mmc 0 0x3000000 uImage
# u-boot> fatload mmc 0 0x2A00000 devicetree.dtb
# u-boot> fatload mmc 0 0x2000000 uramdisk.image.gz
# u-boot> bootm 0x3000000 0x2000000 0x2A00000
#
# With the bootm command, U-Boot is relocating the images before it boots Linux
# such that the addresses above may not be what the kernel sees. U-Boot also
# alters the device tree to tell the kernel where the ramdisk image is located
# in memory (initrd-start and initrd-end). The bootm command sets the r2
# register to the address of the device tree in memory which is not done by the
# go command.
#
# => Once U-Boot has compiled successfully the following files will be created
# in the U-Boot directory:
#
# File          Description
#
# u-boot        Compiled ELF image
# u-boot.bin    u-boot converted to a raw binary
# u-boot.img    U-boot image file
# u-boot.srec   u-boot.bin converted to Motorola S-records format
# u-boot.ldr    u-boot converted to Blackfin Loader format
#
# Generating By Hand
#
# // Convert ELF to Binary
# $ ${CROSS_COMPILE}-objcopy --gap-fill=0xff -O binary u-boot u-boot.bin
#
# // Convert ELF to Hex
# $ ${CROSS_COMPILE}-objcopy --gap-fill=0xff -O ihex u-boot u-boot.hex
#
# // Convert Binary to Hex
# $ ${CROSS_COMPILE}-objcopy --gap-fill=0xff -I binary -O ihex u-boot.bin u-boot.hex
#
# // Convert LDR to Hex
# $ ${CROSS_COMPILE}-objcopy --gap-fill=0xff -I binary -O ihex u-boot.ldr u-boot.ldr.hex
#
# => Booting Linux
#
# XMD or TFTP may be used to download Linux to the FPGA (memory). U-Boot can
# then use these files to boot Linux. Once the kernel, root filesystem, and
# device tree images are present in memory, the command to boot Linux is:
#
# U-Boot> bootm <addr of kernel> <addr of rootfs> <addr of device tree blob (dtb)>
#
# Note: Make sure the kernel and root filesystem images are wrapped by with
# the U-Boot header. The device tree blob does not need to be wrapped with the
# U-Boot header.
#
###############################################################################
# => Help and information
usage() {
    echo "Purpose: build the u-boot and install the image after building."
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
# Compiling and Installing U-Boot
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# => Make sure the source is there
if [ "`ls -A ${ZN_UBOOT_DIR}`" = "" ]; then
    error_exit "Can't find the source code of u-boot !!!"
else
    cd ${ZN_UBOOT_DIR}
fi

# => Building the U-Boot bootloader is a part of the Xilinx design flow.
print_info "Build U-Boot on the ${ZN_UBOOT_DIR} ..."
echo "MAKE_JOBS:" ${MAKE_JOBS}
make ${MAKE_JOBS}
if [ $? -eq 0 ]; then
    # After the compilation, the ELF (Executable and Linkable File) generated is
    # named u-boot.  We need to add the ‘.elf’ extension to the file name so that
    # Xilinx SDK can read the file layout and generate BOOT.BIN.
    #
    ###
    # 1. U-Boot normally
    ###
    # http://www.wiki.xilinx.com/Build+U-Boot
    cp ${ZN_UBOOT_DIR}/u-boot ${ZN_TARGET_DIR}/u-boot.elf

    ###
    # 2. Build U-Boot SPL
    ###
    # The U-Boot Secondary Program Loader (SPL) is capable of replacing the First
    # Stage Boot Loader (FSBL) for booting Zynq.
    #
    # https://wiki.freebsd.org/FreeBSD/arm/Zedboard
    # The Zedboard needs several files in a boot partition.  The file boot.bin is
    # the first executable the Zynq chip boots.  It initializes the Zynq and then
    # hands over execution to u-boot.img.  Both files are built from sources from
    # Xilinx on github.  Release xilinx-v2016.4 is the latest I've tested.
    #
    # http://www.wiki.xilinx.com/U-Boot+Secondary+Program+Loader
    # In order to replace the FSBL, the U-Boot SPL requires hardware specific
    # input files in addition to the standard files needed to build U-Boot.
    #
    # * Generate hardware files (ps7_init_gpl.[ch]) using SDK or obtain generic
    # files from the Xilinx git repository
    #
    # * Copy ps7_init_gpl files to the board/xilinx/zynq/ directory before
    # proceeding to build U-Boot. This is necessary for the U-Boot SPL to replace
    # the FSBL.
    #
    #     These files are part of the hardware specification created by SDK. For
    # more information on building these files, see New Horizons Zynq Blog
    #
    # * If building for QSPI boot mode, it is necessary to ensure that all flash
    # offsets match those in the U-Boot QSPI boot command.
    #
    #      The config symbol for u-boot.img is CONFIG_SYS_SPI_U_BOOT_OFFS; setting
    # this symbol to 0x80000 has been tested as a good offset to enable the SPL flow.
    #
    #  Pitfall warning: make will succeed without the ps7_init_gpl.[ch] files, but
    # the resulting U-Boot SPL will not be able initialize hardware
    #
    # 2.1 Output Files Produced
    #
    # boot.bin   - Zynq boot image
    # u-boot-spl - U-Boot SPL ELF file
    # u-boot.img - U-Boot SPL searches for this file in memory to load U-Boot
    # u-boot     - U-Boot ELF file, use this file if loading U-Boot on top of the
    #              SPL manually (as in JTAG mode)
    #
    # 2.2 Boot using U-Boot SPL
    #
    # 2.2.1. SD Card
    # Prepare the SD card as a boot medium and load it with the following files:
    #
    # boot.bin
    # u-boot.img
    # uImage
    # uramdisk.tar.gz
    # devicetree.dtb
    # bitstream.bit
    #
    # Boot from SD Card as normal. Linux should load automatically, otherwise use
    # bootm at the U-Boot console.
    #
    # 2.2.2 QSPI
    # The QSPI boot preparation consists of programming the following files at the
    # correct addresses, which is where U-Boot expects to find them in its QSPI
    # boot command.
    #
    # Partition         Offset          Block Size (Byte)       Block Size (MB)
    # boot.bin          0x00 0000       0x08 0000               0.524
    # u-boot.img        0x08 0000       0x08 0000               0.524
    # uImage            0x10 0000       0x50 0000               5.243
    # devicetree.dtb    0x60 0000       0x02 0000               0.131
    # uramdisk.image.gz 0x62 0000       0x9e 0000               10.35
    #
    if [ -f "${ZN_UBOOT_DIR}/u-boot.img" ]; then
        cp ${ZN_UBOOT_DIR}/u-boot.img        ${ZN_TARGET_DIR}
        cp ${ZN_UBOOT_DIR}/spl/boot.bin      ${ZN_TARGET_DIR}
    fi

    print_info "U-Boot - Build OK !!!"
else
    error_exit "U-Boot - Build Failed !!!"
fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
