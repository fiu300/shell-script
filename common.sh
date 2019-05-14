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

# => Writing a Warning Message to the Console Window
print_warn() {                   # 黄色字
    local msg="$1"
    printf "\033[33m[WARNING] \033[0m";
    printf "$msg\n";
}
export -f print_warn

# => Writing a Infomation Message to the Console Window
print_info() {                      # 绿色字
    local msg="$1"
    printf "\033[32m[INFO] \033[0m";
    printf "$msg\n";
}
export -f print_info

# => Writing a Error Message to the Console Window
print_error() {                      # 红色字
    local msg="$1"
    printf "\033[31m[ERROR] \033[0m";
    printf "$msg\n";
}
export -f print_error

# => Writing a Error Message to the Console Window and exit
error_exit() {                      # 红色字
    local msg="$1"
    printf "\033[31m[ERROR] \033[0m";
    printf "$msg\n";
    exit 1;
}
export -f error_exit

# => Check the script is being run by root user
check_root() {
    if [ `whoami` != root ]; then
        error_exit "$0 must be run as sudo user or root!"
    fi
}
export -f check_root

# => When the current user isn't root, re-exec the script through sudo.
run_as_root() {
    [ "$(whoami)" != "root" ] && exec sudo -- "$0" "$@"
}
export -f run_as_root

# => This function will return the code name of the Linux host release to the caller
get_host_type() {
    local  __host_type=$1
    local  the_host=`lsb_release -a 2>/dev/null | grep Codename: | awk {'print $2'}`
    eval $__host_type="'$the_host'"
}
export -f get_host_type

# => This function returns the version of the Linux host to the caller
get_host_version() {
    local  __host_ver=$1
    local  the_version=`lsb_release -a 2>/dev/null | grep Release: | awk {'print $2'}`
    eval $__host_ver="'$the_version'"
}
export -f get_host_version

# => This function returns the major version of the Linux host to the caller
# If the host is version 12.04 then this function will return 12
get_major_host_version() {
    local  __host_ver=$1
    get_host_version major_version
    eval $__host_ver="'${major_version%%.*}'"
}
export -f get_major_host_version

# => This function returns the minor version of the Linux host to the caller
# If the host is version 12.04 then this function will return 04
get_minor_host_version() {
    local  __host_ver=$1
    get_host_version minor_version
    eval $__host_ver="'${minor_version##*.}'"
}
export -f get_minor_host_version

# => apt-get wrapper to just get arguments set correctly
function apt-get() {
    local sudo="sudo"
    [ "$(id -u)" = "0" ] && sudo=""
    $sudo DEBIAN_FRONTEND=noninteractive apt-get \
          --optin "Dpkg::Options::=--force-confold" --assume-yes "$@"
}
