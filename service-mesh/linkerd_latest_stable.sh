#!/bin/bash

## should use this for the version of docker image
VERSION=stable-2.14.9

helm repo add linkerd https://helm.linkerd.io/stable

helm repo update

# install CRD (custom resource definition), remove the flag of "--create-namespace" if already has the namesace of linkerd
helm install linkerd-crds linkerd/linkerd-crds -n linkerd #--create-namespace

helm install linkerd-control-plane \
  -n linkerd \
  --set-file identityTrustAnchorsPEM=./secrets/ca.crt \
  --set-file identity.issuer.tls.crtPEM=./secrets/issuer.crt \
  --set-file identity.issuer.tls.keyPEM=./secrets/issuer.key \
  --set proxyInit.runAsRoot=true \
  linkerd/linkerd-control-plane
