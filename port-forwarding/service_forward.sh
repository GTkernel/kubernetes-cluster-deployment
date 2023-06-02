#!/bin/bash

# Object Detect
#NPORT=30851
#CPORT=8501
#HOST_PIP=192.168.1.161 #e.g. 192.168.1.100

#### ROS 
#NPORT=30311
#CPORT=11311
#HOST_PIP=192.168.1.100 #e.g. 192.168.1.100

### Video360
#NPORT=31500
#CPORT=9500
#HOST_PIP=192.168.1.100 #e.g. 192.168.1.100

##### Prom
#NPORT=31552
#CPORT=9090
#HOST_PIP=192.168.1.161 #e.g. 192.168.1.100

# FleXR
NPORT=30909
CPORT=9900
HOST_PIP=192.168.1.161 #e.g. 192.168.1.100

#Accept to forward service traffic to gtue
iptables -I FORWARD -d $HOST_PIP -m tcp -p tcp --dport $NPORT -j ACCEPT
#Accept to forward service return traffic from gtue
iptables -I FORWARD -s $HOST_PIP -m tcp -p tcp --sport $NPORT -j ACCEPT
#Redirect packets to k8s nodeport
iptables -t nat -I PREROUTING -m tcp -p tcp --dport $CPORT -j DNAT --to-destination $HOST_PIP:$NPORT
#NAT the src ip
iptables -t nat -I POSTROUTING -d $HOST_PIP -o eno1 -j MASQUERADE
