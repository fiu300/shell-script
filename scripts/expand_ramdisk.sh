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
# 知识一：
# 如果想要查看某个磁盘分区的文件系统类型，可以使用 blkid DEVICE 命令，如：
#
# [root@localhost ~]# blkid /dev/sdb3
# /dev/sdb3: UUID="259690de-5ec4-4356-b590-02ba11c31730" TYPE="ext4"
#
# 这里可以看到/dev/sdb3这个设备的UUID号和文件系统类型。之所以要为磁盘分区生成UUID
# （全局唯一识别标识），是因为在实际生产环境中，一台服务器上可以挂载的磁盘分区可
# 以达到成千上万台，故需要使用UUID对其进行区分。
#
# 知识二：
# 所谓挂载，就是将某个磁盘分区和一个目录建立关联关系的过程。
# 挂载使用的命令为mount，其格式为：
#
# mount [-t fstype] DEVICE MOUNT_POINT
#
# mount [-t fstype] LABEL=”Volume_label” MOUNT_POINT
#
# mount [-t fstype] UUID=”UUID” MOUNT_POINT
#
# 这里[DEVICE]是要挂载的文件系统，MOUNT_POINT为挂载点，即要挂载的位置。
# 在使用mount命令时，通常需要指定所挂载的文件系统的类型。
# 如果不指定，那么mount命令会自动调用blkid命令来判断该文件系统的类型。
#
# 所谓卸载，就是解除某个磁盘分区和目录的关联关系。
# 卸载（拆除关联关系）使用的命令为umont，其格式为：
#
# umount DEVICE
#
# 或者
#
# umount MOUNT_POINT
#
# 拆除关联关系只需要指定一个，或者是设备，或者是挂载点。
#
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

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
# 确定ramdisk.image.gz文件是否存在
if [ ! -f "${ZN_OUTPUT_DIR}/ramdisk.image.gz" ]; then
    if [ ! -f "${ZN_DOWNLOAD_DIR}/ramdisk.image.gz" ]; then
        error_exit "找不到ramdisk.image.gz"
    else
        cp ${ZN_DOWNLOAD_DIR}/ramdisk.image.gz ${ZN_OUTPUT_DIR}/
    fi
fi

print_info "Make changes in the mounted filesystem..."
mkdir -p ${ZN_OUTPUT_DIR}/ramdisk.old/rootfs
mv ${ZN_OUTPUT_DIR}/ramdisk.image.gz ${ZN_OUTPUT_DIR}/ramdisk.old
gunzip ${ZN_OUTPUT_DIR}/ramdisk.old/ramdisk.image.gz
sudo chmod u+rwx ${ZN_OUTPUT_DIR}/ramdisk.old/ramdisk.image
sudo mount -o loop ${ZN_OUTPUT_DIR}/ramdisk.old/ramdisk.image ${ZN_OUTPUT_DIR}/ramdisk.old/rootfs

sudo cp -rf ${ZN_OUTPUT_DIR}/ramdisk.old/rootfs/* ${ZN_ROOTFS_MOUNT_POINT}

sudo umount ${ZN_OUTPUT_DIR}/ramdisk.old/rootfs
rm -rf ${ZN_OUTPUT_DIR}/ramdisk.old

# ==> 7. Unmount ramdisk image
print_info "Unmount ramdisk image..."
sudo umount ${ZN_ROOTFS_MOUNT_POINT}

# ==> 8. Compress ramdisk image
print_info "Compress ramdisk image..."
gzip ${ZN_TARGET_DIR}/ramdisk.image

# ==> 9. Wrapping the image with a U-Boot header
if ! which mkimage > /dev/null; then
    error_exit "Missing mkimage command !!!"
else
    print_info "Wrapping the image with a U-Boot header..."
    mkimage -A arm -T ramdisk -C gzip -d ${ZN_TARGET_DIR}/ramdisk.image.gz \
        ${ZN_TARGET_DIR}/uramdisk.image.gz
fi


# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
