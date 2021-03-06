#!/bin/sh

# Get password
echo "Enter the new root password for the device."
read -sp 'Password: ' passwd

# Set password to S Defaukt
echo -e "$passwd\n$passwd"

# Update the package manager
opkg update

# Force authentication for TTY and serial logins
uci set system.@system[0].ttylogin="1"
uci commit system
/etc/init.d/system restart

# Set dropbear (The SSH Server) to only listen on LAN
uci set dropbear.@dropbear[0].Interface="lan"
uci commit
/etc/init.d/dropbear restart

# Remove unnecessary rules 
# Remove IGMP
uci delete firewall.@rule[2]
# Remove MLD
uci delete firewall.@rule[3]
# Remove UDP Traceroutes
uci delete firewall.@rule[7]

# Set DNS Servers
uci -q delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server="1.1.1.1"
uci add_list dhcp.@dnsmasq[0].server="1.0.0.1"
uci commit dhcp
/etc/init.d/dnsmasq restart

# set uHTTPd to only listen on LAN network
# Get network address
lannet=$(ifstatus lan |  jsonfilter -e '@["ipv4-address"][0].address')
uci set uhttpd.main.listen_http="$lannet:80"
uci set uhttpd.main.listen_https="$lannet:443"
uci commit
/etc/init.d/uhttpd restart

# Install required packages for modem - serial are optional
opkg update
opkg install luci-proto-qmi kmod-usb-net-cdc-ether kmod-mppe kmod-usb-net kmod-usb-net-rndis
opkg install usb-modeswitch kmod-mii kmod-usb-net kmod-usb-wdm uqmi
opkg install kmod-usb-serial-option kmod-usb-serial kmod-usb-serial-wwan

# Drop in modem interface config
echo "
config interface 'wwan0'
        option ifname 'wwan0'
        option proto 'qmi'
        option device '/dev/cdc-wdm0'
        option apn 'telstra.internet'
        option auth 'none'
        option pdptype 'ipv4v6'
" >> /etc/config/network

/etc/init.d/network restart

# Add interface to WAN firewall
uci add_list firewall.@zone[1].network='wwan0'
uci commit

# Install WireGuard
opkg update && opkg install luci-proto-wireguard




