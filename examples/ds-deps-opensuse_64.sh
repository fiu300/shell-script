#! /bin/sh
#
# Copyright (C) 2013 ARM Ltd. All rights reserved.
#
# ds-deps.sh [--no-install]
# 
# Check for and install the DS-5 system dependencies.
#
#   --no-install  Only check whether the dependencies are installed, do not install
#
#

check_for_package () 
{
    printf "Checking for $1... "
    if `zypper info $1 | grep "Installed: Yes" > /dev/null`; then
        printf "installed\n"
    else
        printf "not installed\n"
        install_package $1
    fi
}

install_package ()
{
    if $install; then
        printf "Installing $1... "
        if `zypper -qn install $1 > /dev/null`; then
            printf "done\n"
        fi
    fi
}

install=true

if [ $# -gt 0 ] ; then
    if [ $1 = "--no-install" ] ; then
        install=false
    else
        echo "Usage: ds-deps.sh [--no-install]"
        echo "Check for and install the DS-5 system dependencies."
        echo ""
        echo "  --no-install  Only check whether the dependencies are installed, do not install"
        exit
    fi
fi

if [ `whoami` != root ] ; then
    echo "Error: Dependency management requires root privileges"
    exit 1
fi

# 64-bit dependencies
check_for_package 'glibc' 
check_for_package 'libgtk-2_0-0' 
check_for_package 'libstdc++6'
check_for_package 'libasound2'
check_for_package 'libatk-1_0-0'
check_for_package 'libcairo2'
check_for_package 'fontconfig'
check_for_package 'libfreetype6'
check_for_package 'libgthread-2_0-0'
check_for_package 'libX11-6'
check_for_package 'libXext6'
check_for_package 'libXi6'
check_for_package 'libXrender1'
check_for_package 'libXt6'
check_for_package 'libXtst6'
check_for_package 'libwebkitgtk-1_0-0'

# 32-bit dependencies
check_for_package 'fontconfig-32bit'
check_for_package 'libfreetype6-32bit'
check_for_package 'libICE6-32bit'
check_for_package 'libncurses5-32bit'
check_for_package 'libSM6-32bit'
check_for_package 'libstdc++6-32bit'
check_for_package 'libusb-0_1-4-32bit'
check_for_package 'libX11-6-32bit'
check_for_package 'libXcursor1-32bit'
check_for_package 'libXext6-32bit'
check_for_package 'libXft2-32bit'
check_for_package 'libXmu6-32bit'
check_for_package 'libXrandr2-32bit'
check_for_package 'libXrender1-32bit'
check_for_package 'libz1-32bit'


printf "Checking for libGL.so.1 (32 bit)... "
if `/sbin/ldconfig -p | grep "libGL.so.1" | grep -v "x86-64" > /dev/null`; then
	printf "found\n"
else
	printf "not found\n"
	install_package 'Mesa-libGL1-32bit'
fi
