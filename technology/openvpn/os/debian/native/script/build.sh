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
# base content:
#   https://community.openvpn.net/openvpn/wiki/HOWTO
#   https://docs.vyos.io/en/equuleus/configuration/interfaces/openvpn.html

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

org_country="BR" # Code of Country Name
org_province="Alagoas" # Province name
org_city="Maceio" # City name
org_co="rick0x00" # Copyleft Certificate Co
org_email="rick.0x00@gmail.com" # email address
org_ou="TI" # Organization Unit

key_size="2048"

openvpn_server_name="central"
openvpn_server_host="192.168.56.22"

openvpn_client_name="client0"

openvpn_private_network_address="10.10.10.0"
openvpn_private_network_lmask="255.255.255.0"
openvpn_private_network_smask="24"

openvpn_port[0]="1194" # OpenVPN number Port listening
openvpn_port[1]="udp" # OpenVPN protocol Port listening

workdir="etc/openvpn"
persistence_volumes=("/etc/openvpn/" "/var/log/openvpn/")
expose_ports="${openvpn_port[0]}/${openvpn_port[1]}"
# end set variables
# ============================================================ #
# start definition functions
# ============================== #
# start complement functions

# end complement functions
# ============================== #
# start main functions

function install_server () {
    # Install OpenVPN 
    apt update
    apt install -y openvpn easy-rsa
}

function configure_easyrsa_vars () {
    # Configure Vars to PKI
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
    sed -i "/#set_var EASYRSA_BATCH/s/#//" /etc/openvpn/easy-rsa/vars

    sed -i "/set_var EASYRSA_DN/s/cn_only/org/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_KEY_SIZE/s/2048/${key_size}/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_COUNTRY/s/US/${org_country}/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_PROVINCE/s/California/${org_province}/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_CITY/s/San Francisco/${org_city}/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_ORG/s/Copyleft Certificate Co/${org_co}/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_EMAIL/s/me@example.net/${org_email}/" /etc/openvpn/easy-rsa/vars
    sed -i "/set_var EASYRSA_REQ_OU/s/My Organizational Unit/${org_ou}/" /etc/openvpn/easy-rsa/vars
    sed -i '/set_var EASYRSA_BATCH/s/""/"yes"/' /etc/openvpn/easy-rsa/vars

}

function create_certificates_for_server () {
    # Create certificates for server
    cd /etc/openvpn/easy-rsa/
    # Removes & re-initializes the PKI dir for a clean PKI
    ./easyrsa init-pki
    # Creates a new CA
    ./easyrsa build-ca nopass # cria ca.crt
    # Generates DH (Diffie-Hellman) parameters
    ./easyrsa gen-dh # cria dh.pem
    # Generate a CRL
    ./easyrsa gen-crl # cria crl.pem
    # Generate a standalone keypair and request (CSR) without password
    ./easyrsa gen-req $openvpn_server_name nopass # cria $openvpn_server_name.key
    # Sign a certificate request
    ./easyrsa sign-req server $openvpn_server_name # cria $openvpn_server_name.crt

    # Generate a new random key of type and write to file
    openvpn --genkey secret ta.key

    mkdir /etc/openvpn/config
    cp pki/ca.crt /etc/openvpn/config
    cp pki/dh.pem  /etc/openvpn/config
    cp pki/crl.pem /etc/openvpn/config
    cp ta.key /etc/openvpn/config

    cp pki/private/${openvpn_server_name}.key /etc/openvpn/config
    cp pki/issued/${openvpn_server_name}.crt  /etc/openvpn/config
} 

function create_certificates_for_client () {
    # Createc certificates for client
    cd /etc/openvpn/easy-rsa/
    # Generate a keypair and sign locally for a client
    ./easyrsa build-client-full $openvpn_client_name nopass

    cp pki/private/${openvpn_client_name}.key /etc/openvpn/config
    cp pki/issued/${openvpn_client_name}.crt /etc/openvpn/config
}


function create_config_file_for_openvpn_server () {
    # Create a Server Config File
    #cp /etc/openvpn/server.conf /etc/openvpn/server.conf.bkp_$(date +%s)
    echo "port ${openvpn_port[0]}
    proto ${openvpn_port[1]}
    dev tun
    ca /etc/openvpn/config/ca.crt
    cert /etc/openvpn/config/${openvpn_server_name}.crt
    key /etc/openvpn/config/${openvpn_server_name}.key 
    dh /etc/openvpn/config/dh.pem
    server ${openvpn_private_network_address} ${openvpn_private_network_lmask}
    ### Settings for the client apply
    ## Create default route to direct internet traffic to vpn
    # poor (includes all default routes from the server machine, Including local network)
    #push \"redirect-gateway def1 bypass-dhcp\"
    # best (include default route only for internet access, Without local network)
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
    # Create a Client vpn config file
    #cp /etc/openvpn/${openvpn_client_name}.ovpn /etc/openvpn/${openvpn_client_name}.ovpn.bkp_$(date +%s)
    echo "client
    dev tun
    remote ${openvpn_server_host} ${openvpn_port[0]}
    proto ${openvpn_port[1]}
    resolv-retry infinite
    nobind
    persist-key
    persist-tun
    #ca [inline]
    #cert [inline]
    #key [inline]
    # the first line below needs to be replaced by the second line below work cirrectly
    #tls-auth [inline] 1
    key-direction 1
    keepalive 10 120
    cipher AES-256-GCM
    auth-nocache
    remote-cert-tls server
    verb 3
    " > /etc/openvpn/${openvpn_client_name}.ovpn

    # Remobve a white apace from beginning of line
    #sed -i 's/^[[:space:]]\+//' /etc/openvpn/${openvpn_client_name}.ovpn
    #sed -i 's/^[[:blank:]]\+//' /etc/openvpn/${openvpn_client_name}.ovpn
    sed -i 's/^ \+//' /etc/openvpn/${openvpn_client_name}.ovpn

    echo "<ca>" >> /etc/openvpn/${openvpn_client_name}.ovpn
    cat /etc/openvpn/config/ca.crt >> /etc/openvpn/${openvpn_client_name}.ovpn
    echo -e "</ca>\n" >> /etc/openvpn/${openvpn_client_name}.ovpn

    echo "<cert>" >> /etc/openvpn/${openvpn_client_name}.ovpn
    cat /etc/openvpn/config/${openvpn_client_name}.crt >> /etc/openvpn/${openvpn_client_name}.ovpn
    echo -e "</cert>\n" >> /etc/openvpn/${openvpn_client_name}.ovpn
    
    echo "<key>" >> /etc/openvpn/${openvpn_client_name}.ovpn
    cat /etc/openvpn/config/${openvpn_client_name}.key >> /etc/openvpn/${openvpn_client_name}.ovpn
    echo -e "</key>\n" >> /etc/openvpn/${openvpn_client_name}.ovpn
    
    echo "<tls-auth>" >> /etc/openvpn/${openvpn_client_name}.ovpn
    cat /etc/openvpn/config/ta.key >> /etc/openvpn/${openvpn_client_name}.ovpn
    echo -e "</tls-auth>\n" >> /etc/openvpn/${openvpn_client_name}.ovpn
}

function enabling_nat_for_vpn_network () {
    # Creates a firewall rule to NAT the traffic from the source of the VPN network, destined for the interface with internet access
    iptables -t nat -A POSTROUTING -s ${openvpn_private_network_address}/${openvpn_private_network_smask} -o eth0 -j MASQUERADE
}

function enabling_routing_between_interfaces () {
    # Enable routing between network interfaces
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
}

function configure_server () {
    configure_easyrsa_vars;
    create_certificates_for_server;
    create_certificates_for_client;
    create_config_file_for_openvpn_server;
    create_config_file_for_openvpn_client;
    enabling_nat_for_vpn_network;
    enabling_routing_between_interfaces;
}

function start_server () {
    # Stop openVPN service
    systemctl stop openvpn
    systemctl stop openvpn@server
    # Enable openVPN Server service
    systemctl enable --now openvpn@server
    # Start OpenVPN Serve service
    systemctl start openvpn@server
    # /usr/sbin/openvpn --daemon ovpn-server --status /run/openvpn/server.status 10 --cd /etc/openvpn --config /etc/openvpn/server.conf --writepid /run/openvpn/server.pid
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
install_server;
configure_server;
start_server;
