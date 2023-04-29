#!/usr/bin/env bash

# ============================================================ #
# Tool Created date: 29 abr 2023                               #
# Tool Created by: Henrique Silva (rick.0x00@gmail.com)        #
# Tool Name: srv_vpn (OpenVPN)                                 #
# Description: My Script to Create OpenVPN Servers             #
# License: MIT License                                         #
# Remote repository 1: https://github.com/rick0x00/srv_vpn     #
# Remote repository 2: https://gitlab.com/rick0x00/srv_vpn     #
# ============================================================ #

# ============================================================ #
# start root user checking
if [ $(id -u) -ne 0 ]; then
    echo "Please use root user to run the script."
    exit 1
fi
# end root user checking
# ============================================================ #
# start set variables

os_distribution="debian"
os_version=("11" "bullseye")

port[0]="XPTO" # description
port[1]="bar" # description

workdir="workdir"
persistence_volumes=("persistence_volume_N" "Logs")
expose_ports="${port[0]}/tcp ${port[1]}/udp"
# end set variables
# ============================================================ #
# start definition functions
# ============================== #
# start complement functions

# end complement functions
# ============================== #
# start main functions
function pre_install_server () {
}

function install_server () {
    
}

function configure_server () {
}

function start_server () {
}


# end main functions
# ============================== #
# end definition functions
# ============================================================ #
# start argument reading

# end argument reading
# ============================================================ #
# start main executions of code
install_server;
configure_server;
start_server;
