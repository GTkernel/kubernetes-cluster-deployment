#!/bin/bash

NPORT=  #e.g. 31499
CPORT=  #e.g. 9090
HOST_PIP= #e.g. 192.168.1.100

#Accept to forward service traffic to gtue
iptables -I FORWARD -d $HOST_PIP -m tcp -p tcp --dport $NPORT -j ACCEPT
#Accept to forward service return traffic from gtue
iptables -I FORWARD -s $HOST_PIP -m tcp -p tcp --sport $NPORT -j ACCEPT
#Redirect packets to k8s nodeport
iptables -t nat -I PREROUTING -m tcp -p tcp --dport $CPORT -j DNAT --to-destination $HOST_PIP:$NPORT
#NAT the src ip
iptables -t nat -I POSTROUTING -d $HOST_PIP -o eno1 -j MASQUERADE
