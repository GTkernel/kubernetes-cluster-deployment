#!/bin/bash

MASTER_PRIVATE_IP=""
PRIVATE_CIDR=""

ifconfig eno1:0 $MASTER_PRIVATE_IP
iptables -t nat -A POSTROUTING -s $PRIVATE_CIDR ! -d $PRIVATE_CIDR -j MASQUERADE
iptables -A INPUT -i eno1:0 -j ACCEPT
iptables -A FORWARD -i eno1:0 -j ACCEPT
