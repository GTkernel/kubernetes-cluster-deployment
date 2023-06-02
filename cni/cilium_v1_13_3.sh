#!/bin/bash

VERSION=1.13.3
MASTER_PRIVATE_IP=192.168.1.160

helm repo add cilium https://helm.cilium.io/

helm repo update
## for replacing proxy
helm install cilium cilium/cilium --version 1.13.3 --namespace kube-system --set kubeProxyReplacement=strict --set k8sServiceHost=$MASTER_PRIVATE_IP --set k8sServicePort=6443


#### after cilium installed, for enable hubble, w/ or w/o UI
#helm upgrade cilium cilium/cilium --version 1.11.4 \
#   --namespace kube-system \
#   --reuse-values \
#   --set hubble.listenAddress=":4244" \
#   --set hubble.relay.enabled=true \
#   --set hubble.ui.enabled=false
