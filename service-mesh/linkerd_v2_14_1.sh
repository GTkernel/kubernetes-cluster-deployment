#!/bin/bash

helm repo add linkerd https://helm.linkerd.io/stable

# install CRD (custom resource definition), remove the flag of "--create-namespace" if already has the namesace of linkerd
helm install linkerd-crds linkerd/linkerd-crds -n linkerd --create-namespace

helm install linkerd-control-plane \
  -n linkerd \
  --set-file identityTrustAnchorsPEM=ca.crt \
  --set-file identity.issuer.tls.crtPEM=issuer.crt \
  --set-file identity.issuer.tls.keyPEM=issuer.key \
  linkerd/linkerd-control-plane
