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
# https://buildroot.org/downloads/manual/manual.html
# http://www.wiki.xilinx.com/Build+and+Modify+a+Rootfs
# http://www.wiki.xilinx.com/Build+Linux+for+Zynq-7000+AP+SoC+using+Buildroot
#
###############################################################################
# => Help and information
usage() {
    echo "Purpose: Compiling and Installing Buildroot"
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
# Compiling and Installing Buildroot
# Note: You should never use make -jN with Buildroot
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# => Try lsb_release, fallback with /etc/issue then uname command
distributions="(Debian|Ubuntu|RedHat|CentOS|openSUSE|SUSE)"
distribution=$(                                             \
    lsb_release -d 2>/dev/null | grep -Eo $distributions    \
    || grep -Eo $distributions /etc/issue 2>/dev/null       \
    || grep -Eo $distributions /etc/*-release 2>/dev/null   \
    || uname -s                                             \
    )

case ${distribution} in
    CentOS)
        # You have PERL_MM_OPT defined because Perl local::lib
        # is installed on your system. Please unset this variable
        # before starting Buildroot, otherwise the compilation of
        # Perl related packages will fail
        unset PERL_MM_OPT
        ;;
    *)
        ;;
esac

# => Make sure the source is there
if [ "`ls -A ${ZN_BUILDROOT_DIR}`" = "" ]; then
    error_exit "Can't find the source code of buildroot !!!"
else
    cd ${ZN_BUILDROOT_DIR}
fi

# => Compiling Buildroot
make
if [ "$?" -ne 0 ]; then
    error_exit "根文件系统编译失败！！！"
fi

# => Housekeeping...
sudo rm -rf ${ZN_ROOTFS_MOUNT_POINT}/*
sudo rm -f  ${ZN_TARGET_DIR}/ramdisk.image
sudo rm -f  ${ZN_TARGET_DIR}/ramdisk.image.gz

echo "******************************************"
echo  ${ZN_ROOTFS_MOUNT_POINT} 
echo ${ZN_TARGET_DIR}
echo ${ZN_BUILDROOT_DIR} 
echo "******************************************"

# => Installing Buildroot
# ==> 1. Create an empty ramdisk image
print_info "Create an empty ramdisk image..."
# 创建一个64MB大小的ramdisk镜像，此时ramdisk.image文件里面没有任何目录，可以通
# 过hexdump命令看到里面是全0.
dd if=/dev/zero of=${ZN_TARGET_DIR}/ramdisk.image bs=${ZN_BLOCK_SIZE} count=${ZN_RAMDISK_SIZE}

# ==> 2. Create an ext2/ext3/ext4 filesystem
print_info "Create an ext2/ext3/ext4 filesystem..."
# 此时通过hexdump命令可以看到里面已经有了一些数据
sudo mke2fs -t ext4 -F ${ZN_TARGET_DIR}/ramdisk.image -L ramdisk -b ${ZN_BLOCK_SIZE} -m 0

# ==> 3. 禁用时间检查
print_info "禁用时间检查..."
# tune2fs是调整和查看ext2/ext3文件系统的文件系统参数，Windows下面如果出现意外断
# 电死机情况，下次开机一般都会出现系统自检。Linux系统下面也有文件系统自检，而且
# 是可以通过tune2fs命令，自行定义自检周期及方式。
sudo tune2fs ${ZN_TARGET_DIR}/ramdisk.image -i 0

# ==> 4. 改变ramdisk.image的访问属性
print_info "改变 ramdisk.image 的访问属性..."
chmod a+rwx ${ZN_TARGET_DIR}/ramdisk.image

# ==> 5. 将ramdisk.image挂载到rootfs目录
print_info "将 ramdisk.image 挂载到 ${ZN_ROOTFS_MOUNT_POINT} 目录..."
sudo mount -o loop ${ZN_TARGET_DIR}/ramdisk.image ${ZN_ROOTFS_MOUNT_POINT}

# ==> 6. Make changes in the mounted filesystem.
if [ ! -f "${ZN_BUILDROOT_DIR}/output/images/rootfs.tar" ]; then
    error_exit "找不到rootfs.tar !!!"
else
    print_info "Make changes in the mounted filesystem..."
    sudo tar xvf ${ZN_BUILDROOT_DIR}/output/images/rootfs.tar -C ${ZN_ROOTFS_MOUNT_POINT}
    sudo cp ${script_dir}/S60mount_emmc.sh /${ZN_ROOTFS_MOUNT_POINT}/etc/init.d/S60mount_emmc.sh
fi

# ==> 7. Unmount ramdisk image
print_info "Unmount ramdisk image..."
sudo umount ${ZN_ROOTFS_MOUNT_POINT}

# ==> 8. Compress ramdisk image
print_info "Compress ramdisk image..."
gzip ${ZN_TARGET_DIR}/ramdisk.image

# ==> 9. Wrapping the image with a U-Boot header
#if ! which mkimage > /dev/null; then
if type mkimage >/dev/null 2>&1; then
    print_info "Wrapping the image with a U-Boot header..."
    mkimage -A arm -T ramdisk -C gzip -d ${ZN_TARGET_DIR}/ramdisk.image.gz \
        ${ZN_TARGET_DIR}/uramdisk.image.gz
else
    error_exit "Missing mkimage command !!!"
fi

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
