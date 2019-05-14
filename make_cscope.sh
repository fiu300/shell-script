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
# https://courses.cs.washington.edu/courses/cse451/12sp/tutorials/tutorial_cscope.html
#
###############################################################################
# => Help and information
usage() {
    echo "Purpose: To configure the linux kernel"
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
# cscope的选项分析：
# -R     ：表示包含此目录的子目录，而非仅仅是当前目录；
# -b     ：此参数告诉cscope生成数据库后就自动退出；
# -q     ：生成cscope.in.out和cscope.po.out文件，加快cscope的索引速度
#
# 可能会用到的其他选项：
# -k     ：在生成索引时，不搜索/usr/include目录；
# -i     ：如果保存文件列表的文件名不是cscope.files时，需要加此选项告诉cscope到哪里去找源文件列表；
# -I dir ：在-I选项指出的目录中查找头文件
# -u     ：扫描所有文件，重新生成交叉索引文件；
# -C     ：在搜索时忽略大小写；
# -P path：在以相对路径表示的文件前加上的path，这样你不用切换到你数据库文件的目录也可以使用它了。
#
# 说明：要在VIM中使用cscope的功能，需要在编译Vim时选择”+cscope”。Vim的cscope接口会先调用cscope的命
#       令行接口，然后分析其输出结果找到匹配处显示给用户。
###############################################################################
# => The beginning
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Starting $script_name"

# Generate cscope.files with a list of files to be scanned.
# The following command will recursively find all of the .c, .cpp, .h, and .hpp files in your current
# directory and any subdirectories, and store the list of these filenames in cscope.files:
find . -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" > cscope.files
# Depending on your project, you can use additional file extensions in this command, such as .java, .py, .s, etc.

# Generate the Cscope database.
cscope -q -R -b -i cscope.files

# => The end
print_info "$(date "+%Y.%m.%d-%H.%M.%S") : Finished $script_name"
