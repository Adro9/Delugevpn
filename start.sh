#!/bin/bash

# create the tun device
[ -d /dev/net ] || mkdir -p /dev/net
[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200

# setup route for deluge web ui
DEFAULT_GATEWAY=$(ip route show default | awk '/default/ {print $3}')

if [ -z "${HOST_SUBNET}" ]; then
	echo "[warn] HOST_SUBNET not specified, deluge web interface will not work"
else
	ip route add $HOST_SUBNET via $DEFAULT_GATEWAY
fi

echo "[info] current route"
ip route
echo "--------------------"

######
# create blocking rules

# accept output to tunnel adapter
iptables -A OUTPUT -o tun0 -j ACCEPT

# accept output to vpn gateway
iptables -A OUTPUT -p udp -o eth0 --dport 1194 -j ACCEPT

# accept output to deluge webui port 8112
iptables -A OUTPUT -p tcp -o eth0 --dport 8112 -j ACCEPT
iptables -A OUTPUT -p tcp -o eth0 --sport 8112 -j ACCEPT

# accept output dns lookup
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

# accept output to local loopback
iptables -A OUTPUT -o lo -j ACCEPT

# reject non matching output traffic
iptables -A OUTPUT -j REJECT

#######

# add in google public nameservers (isp ns may block lookup when connected to vpn)
echo '8.8.8.8' >> /etc/resolv.conf
echo '8.8.4.4' >> /etc/resolv.conf

# run openvpn to create tunnel
/usr/bin/openvpn --cd /config --config /config/openvpn.conf