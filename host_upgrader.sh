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
    echo "Purpose: "
    echo "Version: V2018.03"
    echo "Usage  : $(basename ${BASH_SOURCE}) [option]"
    echo "options:"
    echo "--help: Display this help message"
    exit 0;
}
expr "$*" : ".*--help" > /dev/null && usage

# => Writing a Warning Message to the Console Window
function print_warn() {                   # 黄色字
    local msg="$1"
    printf "\033[33m[WARNING] \033[0m";
    printf "$msg\n";
}

# => Writing a Infomation Message to the Console Window
function print_info() {                      # 绿色字
    local msg="$1"
    printf "\033[32m[INFO] \033[0m";
    printf "$msg\n";
}

# => Writing a Error Message to the Console Window
function print_error() {                      # 红色字
    local msg="$1"
    printf "\033[31m[ERROR] \033[0m";
    printf "$msg\n";
}

# => Writing a Error Message to the Console Window and exit
function error_exit() {                      # 红色字
    local msg="$1"
    printf "\033[31m[ERROR] \033[0m";
    printf "$msg\n";
    exit 1;
}

# => Install a terminal emulator which allows talking to the board.
# http://www.wiki.xilinx.com/Setup+a+Serial+Console

function setup_putty() {
    if ! which putty > /dev/null; then
        print_info "Installing putty ..."
        sudo apt-get --assume-yes install putty putty-doc

        print_info "Create a Desktop Shortcut From the Command Line ..."
        cat > ~/Desktop/Putty.desktop << EOF
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=putty
Icon=putty
Comment=Putty
Exec=/usr/bin/putty
EOF

        chmod 755 ~/Desktop/Putty.desktop

        print_info "Start putty by typing the following: "
        echo "putty"
    fi
}

function setup_screen() {
    if ! which screen > /dev/null; then
        print_info "Installing screen ..."
        sudo apt-get --assume-yes install screen

        print_info "Start screen by typing the following: "
        echo "screen /dev/ttyUSB0 115200 -T xterm"
    fi
}

function setup_minicom() {
    if ! which minicom > /dev/null; then
        print_info "Installing minicom ..."
        sudo apt-get --assume-yes install minicom

        print_info "Start minicom by typing the following: "
        echo "minicom -b 115200 -D /dev/ttyUSB0"
    fi
}

function setup_picocom() {
    if ! which picocom > /dev/null; then
        print_info "Installing picocom ..."
        sudo apt-get --assume-yes install picocom

        print_info "Start picocom by typing the following: "
        echo "picocom -b 115200 -r -l /dev/ttyUSB0"
    fi
}

function setup_cutecom() {
    if ! which cutecom > /dev/null; then
        print_info "Installing cutecom ..."
        sudo apt-get --assume-yes install cutecom

        print_info "Start cutecom by typing the following: "
        echo "cutecom"
    fi
}

function setup_ckermit() {
    if ! which ckermit > /dev/null; then
        print_info "Installing ckermit ..."
        sudo apt-get --assume-yes install ckermit

        print_info "Start ckermit by typing the following: "
        echo "ckermit"
    fi
}

# => Check for dependencies
function check_dependencies() {
    packages="build-essential flex bison bison-doc libncurses5 libncurses5-dev \
        ncurses-doc u-boot-tools device-tree-compiler libssl-dev vim emacs     \
        git mercurial exuberant-ctags cscope graphviz graphviz-doc curl        \
        wget uget p7zip-full rar unrar zip unzip ibus-table-wubi virtualbox    \
        vlc smplayer chromium-browser unity-chromium-extension                 \
        unity-tweak-tool"

    for package in $packages ; do
        dpkg-query -W -f='${Package}\n' | grep ^$package$ > /dev/null
        if [ $? != 0 ] ; then
            print_info "Installing ${package} ..."
            sudo apt-get --assume-yes install ${package}
        fi
    done
}

# => main
function main() {
    # => 因为Vivado不支持x86，故这里做了限制
    ARCH=$(uname -m)
    if [ "$ARCH" == "i686" -o "$ARCH" == "i386" -o "$ARCH" == "x86" ]; then
        error_exit "\033[31mOnly available for 64 bit machines.\033[0m\n"
    fi

    # => Sudo without password on Ubuntu
    print_info "Automatically add current user to the sudoers file"
    if sudo grep -q "$USER ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
        print_info "passwordless sudo already active"
    else
        print_info "setting sudo without password for $USER";
        echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo bash -c '(EDITOR="tee -a" visudo)'
    fi

    # => Distribution Detection
    # Try lsb_release, fallback with /etc/issue then uname command
    distributions="(Debian|Ubuntu|RedHat|CentOS|openSUSE|SUSE)"
    distribution=$(							                    \
        lsb_release -d 2>/dev/null | grep -Eo $distributions	\
        || grep -Eo $distributions /etc/issue 2>/dev/null 	    \
        || grep -Eo $distributions /etc/*-release 2>/dev/null	\
        || uname -s						                        \
        )

    case ${distribution} in
        Debian)
            ;;
        Ubuntu)
            # http://www.wiki.xilinx.com/Install+Xilinx+tools
            # Platform specific hints & tips
            # Ubuntu 12.04 LTS x86_64 users may run into issues related to missing
            # dependencies when installing the Xilinx tools. This release of Ubuntu lacks
            # some needed 32-bit libraries which need to be installed. This can be done by
            # executing

            # Update the Package Index:
            # The APT package index is essentially a database of available packages from
            # the repositories defined in the /etc/apt/sources.list file and in the
            # /etc/apt/sources.list.d directory. To update the local package index with
            # the latest changes made in the repositories, type the following:
            print_info "Update the Package Database ..."
            sudo apt-get --assume-yes update

            # Upgrade Packages:
            # Over time, updated versions of packages currently installed on your computer
            # may become available from the package repositories (for example security
            # updates). To upgrade your system, first update your package index as outlined
            # above, and then type:
            print_info "Upgrade Installed Packages ..."
            sudo apt-get --assume-yes upgrade

            # => Installing Generic dependencies
            print_info "Installing Generic dependencies ..."
            sudo apt-get --assume-yes install build-essential flex bison bison-doc fakeroot \
                curl wget p7zip-full rar unrar zip unzip vlc smplayer graphviz graphviz-doc

            # => Installing the ncurses library
            print_info "Installing the ncurses library ..."
            sudo apt-get --assume-yes install libncurses5 libncurses5-dev ncurses-doc

            # => Installing U-Boot build dependencies
            print_info "Installing U-Boot build dependencies ..."
            sudo apt-get --assume-yes install libssl-dev device-tree-compiler u-boot-tools

            # => Xilinx SDK use the command gmake not make. A symbolic link is needed to solve this problem.
            if [ ! -f /usr/bin/gmake ]; then
                print_info "Fix missing gmake."
                sudo ln -s /usr/bin/make /usr/bin/gmake
            fi

            # => Packages required for 64-bit Ubuntu
            if uname -a|grep -sq 'x86_64'; then
                print_info "Fix missing libraries 32 bits."
                sudo apt-get --assume-yes install lib32ncurses5 lib32z1
            fi

            # => Fixed: /bin/bash: line 9: makeinfo: command not found
            sudo apt-get --assume-yes install texinfo

            # => Serial Terminal Program Rundown for Linux
            print_info "Installing serial terminal program ..."
            # 1. dialout: gives non-root access to serial connections
            sudo usermod -a -G dialout ${USER}
            # 2. Setup Serial Communication Program
            setup_putty && setup_screen

            # => Archive Manager
            print_info "Install MPlayer..."
            sudo apt-get --assume-yes install rar unrar p7zip

            # => MPlayer是一款开源多媒体播放器，以GNU通用公共许可证发布。
            print_info "Install MPlayer..."
            sudo apt-get --assume-yes install smplayer

            # => This command removes .deb files for packages that are no longer installed on your system.
            print_info "Cleaning up of partial package ..."
            sudo apt-get --assume-yes autoclean

            # => This command removes packages that were installed by other packages and are no longer needed.
            print_info "Cleaning up of any unused dependencies ..."
            sudo apt-get --assume-yes autoremove
            ;;
        CentOS)
            ;;
        openSUSE)
            ;;
        *)
            error_exit "Your OS or distribution are not supported by this script."
            ;;
    esac
}

# start
main
