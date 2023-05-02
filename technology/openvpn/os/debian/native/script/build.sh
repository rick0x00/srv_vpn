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

function install_server () {
    apt update
    apt install -y openvpn easy-rsa
}

function configure_easyrsa_vars () {
    cp -r /usr/share/easy-rsa /etc/openvpn
    cp /etc/openvpn/easy-rsa/vars.example /etc/openvpn/easy-rsa/vars
    sed -i "/#set_var EASYRSA_DN/s/#//" /etc/openvpn/easy-rsa/vars
    sed -i "/#set_var EASYRSA_KEY_SIZE/s/#//" /etc/openvpn/easy-rsa/vars
    sed -i "/#set_var EASYRSA_REQ_COUNTRY/s/#//" /etc/openvpn/easy-rsa/vars
    sed -i "/#set_var EASYRSA_REQ_PROVINCE/s/#//" /etc/openvpn/easy-rsa/vars
    sed -i "/#set_var EASYRSA_REQ_CITY/s/#//" /etc/openvpn/easy-rsa/vars
    sed -i "/#set_var EASYRSA_REQ_ORG/s/#//" /etc/openvpn/easy-rsa/vars
    sed -i "/#set_var EASYRSA_REQ_EMAIL/s/#//" /etc/openvpn/easy-rsa/vars
    sed -i "/#set_var EASYRSA_REQ_OU/s/#//" /etc/openvpn/easy-rsa/vars

    sed -i "/set_var EASYRSA_DN/s/cn_only/org/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_KEY_SIZE/s/2048/2048/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_COUNTRY/s/US/BR/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_PROVINCE/s/California/Alagoas/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_CITY/s/San Francisco/Maceio/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_ORG/s/Copyleft Certificate Co/Copyleft Certificate rick0x00/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_EMAIL/s/me@example.net/rick.0x00@gmail.com/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_OU/s/My Organizational Unit/rick0x00/" /etc/openvpn/easy-rsa/vars

}

function create_certificates_for_server () {
    cd /etc/openvpn/easy-rsa/
    ./easyrsa init-pki
    ./easyrsa build-ca nopass # cria ca.crt
    ./easyrsa gen-dh # cria dh.pem
    ./easyrsa gen-crl # cria crl.pem, para que server ?
    ./easyrsa gen-req central nopass # cria central.key
    ./easyrsa sign-req server central # cria central.crt

    openvpn --genkey secret ta.key

    mkdir /etc/openvpn/config
    cp pki/ca.crt /etc/openvpn/config
    cp pki/dh.pem  /etc/openvpn/config
    cp pki/crl.pem /etc/openvpn/config
    cp ta.key /etc/openvpn/config

    cp pki/private/central.key /etc/openvpn/config
    cp pki/issued/central.crt  /etc/openvpn/config
} 

function create_certificates_for_client () {
    cd /etc/openvpn/easy-rsa/
    ./easyrsa build-client-full client0 nopass

    cp pki/private/client0.key /etc/openvpn/config
    cp pki/issued/client0.crt /etc/openvpn/config
}


function create_config_file_for_openvpn_server () {
    #cp /etc/openvpn/server.conf /etc/openvpn/server.conf.bkp_$(date +%s)
    echo "port 1194
    proto udp
    dev tun
    ca /etc/openvpn/config/ca.crt
    cert /etc/openvpn/config/central.crt
    key /etc/openvpn/config/central.key 
    dh /etc/openvpn/config/dh.pem
    server 10.10.10.0 255.255.255.0
    #push \"redirect-gateway def1 bypass-dhcp\"
    push \"route 0.0.0.0 0.0.0.0 vpn_gateway\"
    push \"dhcp-option DNS 1.1.1.1\"
    push \"dhcp-option DNS 8.8.4.4\"
    keepalive 10 120
    tls-auth /etc/openvpn/config/ta.key 0
    cipher AES-256-GCM
    max-clients 10
    user nobody
    group nogroup
    persist-key
    persist-tun
    ifconfig-pool-persist /etc/openvpn/ipp.txt
    status /etc/openvpn/openvpn-status.log
    log /var/log/openvpn/openvpn.log
    verb 3
    " > /etc/openvpn/server.conf
    #sed -i 's/^[[:space:]]\+//' /etc/openvpn/server.conf
    #sed -i 's/^[[:blank:]]\+//' /etc/openvpn/server.conf
    sed -i 's/^ \+//' /etc/openvpn/server.conf
}

function create_config_file_for_openvpn_client () {
    #cp /etc/openvpn/client0.ovpn /etc/openvpn/client0.ovpn.bkp_$(date +%s)
    echo "client
    dev tun
    remote 192.168.56.22 1194
    proto udp
    resolv-retry infinite
    nobind
    persist-key
    persist-tun
    #ca [inline]
    #cert [inline]
    #key [inline]
    #tls-auth [inline] 1
    key-direction 1
    keepalive 10 120
    cipher AES-256-GCM
    auth-nocache
    remote-cert-tls server
    verb 3
    " > /etc/openvpn/client0.ovpn

    #sed -i 's/^[[:space:]]\+//' /etc/openvpn/client0.ovpn
    #sed -i 's/^[[:blank:]]\+//' /etc/openvpn/client0.ovpn
    sed -i 's/^ \+//' /etc/openvpn/client0.ovpn

    echo "<ca>" >> /etc/openvpn/client0.ovpn
    cat /etc/openvpn/config/ca.crt >> /etc/openvpn/client0.ovpn
    echo -e "</ca>\n" >> /etc/openvpn/client0.ovpn
    echo "<cert>" >> /etc/openvpn/client0.ovpn
    cat /etc/openvpn/config/client0.crt >> /etc/openvpn/client0.ovpn
    echo -e "</cert>\n" >> /etc/openvpn/client0.ovpn
    echo "<key>" >> /etc/openvpn/client0.ovpn
    cat /etc/openvpn/config/client0.key >> /etc/openvpn/client0.ovpn
    echo -e "</key>\n" >> /etc/openvpn/client0.ovpn
    echo "<tls-auth>" >> /etc/openvpn/client0.ovpn
    cat /etc/openvpn/config/ta.key >> /etc/openvpn/client0.ovpn
    echo -e "</tls-auth>\n" >> /etc/openvpn/client0.ovpn
}

function enabling_nat_for_vpn_network () {
    iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o eth0 -j MASQUERADE
}

function enabling_routing_between_interfaces () {
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
}

function configure_server () {
    #configure_easyrsa_vars;
    #create_certificates_for_server;
    #create_certificates_for_client;
    create_config_file_for_openvpn_server;
    create_config_file_for_openvpn_client;
    #enabling_nat_for_vpn_network;
    #enabling_routing_between_interfaces;
}

function start_server () {
    systemctl stop openvpn
    systemctl stop openvpn@server
    systemctl enable --now openvpn@server
    systemctl start openvpn@server
    systemctl status --no-pager -l openvpn@server
}

# end main functions
# ============================== #
# end definition functions
# ============================================================ #
# start argument reading

# end argument reading
# ============================================================ #
# start main executions of code
#install_server;
configure_server;
start_server;
