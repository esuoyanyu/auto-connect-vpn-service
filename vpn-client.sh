#!/bin/bash

# Copyright [2023] [esuoyanyu]. All rights reserved.
# Use of this source code is governed by a MIT-style
# license that can be found in the LICENSE file.

NET_INTERFACE=enp1s0

connect_vpn() {
	# 1. connect VPN
	ipsec up esuoyanyu
	if [ $? -ne 0 ]; then
		logger -t 'VPN' "ipsec up is fail"
		return 1
	fi

	echo "c esuoyanyu" > /var/run/xl2tpd/l2tp-control
	if [ $? -ne 0 ]; then
		logger -t 'VPN' "l2tp connect fail"
		return 1
	fi

	try=20
	while true; do
		VPN_LOCAL_PUBLIC_IP=$(ip addr show | awk '/ppp0/ {find=1} find==1 && /inet/ {print $2; exit}')
		if [ "$VPN_LOCAL_PUBLIC_IP" != "" -o $try -eq 0 ]; then
			break;
		fi
		sleep 0.5
		try=$((try - 1))
	done

	logger -t 'VPN' "VPN_LOCAL_PUBLIC_IP=$VPN_LOCAL_PUBLIC_IP"
	if [ $try -eq 0 ]; then
		logger -t 'VPN' "try = $try"
		disconnect_vpn
		return 1
	fi

	VPN_SERVICE_PUBLIC_IP="119.28.135.58"
	GATEWAY_DEFAULT=$(ip route | awk '{ print $3; exit }')
	if [ "$GATEWAY_DEFAULT" == "" -o "$VPN_LOCAL_PUBLIC_IP" == "" ]; then
		logger -t 'VPN' "GATEWAY_DEFAULT=$GATEWAY_DEFAULT or VPN_LOCAL_PUBLIC_IP=$VPN_LOCAL_PUBLIC_IP"
		return 1
	fi

	logger -t 'VPN' "GATEWAY_DEFAULT=$GATEWAY_DEFAULT"

	route add $VPN_SERVICE_PUBLIC_IP gw $GATEWAY_DEFAULT
	route add $VPN_LOCAL_PUBLIC_IP gw $GATEWAY_DEFAULT
	route add default dev ppp0

	resolvectl default-route $NET_INTERFACE false
	resolvectl default-route ppp0 true
	while read line; do
		name_service=$(echo $line | awk '{print $2; exit}')
		resolvectl dns ppp0 $name_service
		break
	done < /etc/ppp/resolv.conf
	resolvectl reset-statistics

	logger -t 'VPN' "GATEWAY_DEFAULT=$GATEWAY_DEFAULT VPN_LOCAL_PUBLIC_IP=$VPN_LOCAL_PUBLIC_IP"
	logger -t 'VPN' "connect vpn service success ret=$?"

	return 0
}

disconnect_vpn() {
	# remove route
	VPN_LOCAL_PUBLIC_IP=$(ip addr show | awk '/ppp0/ {find=1} find==1 && /inet/ {print $2; exit}')
	VPN_SERVICE_PUBLIC_IP="119.28.135.58"
	GATEWAY_DEFAULT=$(ip route | awk '{ if ($3 != "ppp0") { print $3; exit } }')

	logger -t 'VPN' "disconnet GATEWAY_DEFAULT=$GATEWAY_DEFAULT VPN_LOCAL_PUBLIC_IP=$VPN_LOCAL_PUBLIC_IP"

	is_exist_interface=$(ip show addr | grep -w ppp0)
	if [ "$is_exist_interface" != "" ]; then
		resolvectl default-route ppp0 false
	fi
	resolvectl default-route $NET_INTERFACE true
	resolvectl dns $NET_INTERFACE $GATEWAY_DEFAULT
	resolvectl reset-statistics

	route del $VPN_SERVICE_PUBLIC_IP gw $GATEWAY_DEFAULT
	route del $VPN_LOCAL_PUBLIC_IP gw $GATEWAY_DEFAULT
	route del default dev ppp0

	echo "d esuoyanyu" > /var/run/xl2tpd/l2tp-control
	if [ $? -ne 0 ]; then
		logger -t 'VPN' "l2tp disconnect fail"
		return 1
	fi

	ipsec down esuoyanyu
	if [ $? -ne 0 ]; then
		logger -t 'VPN' "ipsec down is fail"
		return 1
	fi

	logger -t 'VPN' "disconnect vpn service success"

	return 0
}

case "$1" in
	"connect")
		connect_vpn
	;;
	"disconnect")
		disconnect_vpn
	;;
	*)
		echo "USAGE [connect/disconnect] vpn"
	;;
esac
