# Kubernetes deployment 

## Introduction

This documentation/installation steps is for building a small, private, and research-facing Kubernetes cluster.
 
The most instructions refer to the [official document](https://kubernetes.io/docs/setup/).
For the setup of Docker registry and Prometheus, we refer to the book of [DevOps with Kubernetes](https://github.com/PacktPublishing/DevOps-with-Kubernetes-Second-Edition)

## Hardware Specification

- Four nodes with Intel i7 (12 processors) and 32 GB RAM
- Nodes are connected with ethernet switch
- Only master node has the public IP, so other nodes are communicated through private network (e.g. `192.168.1.0/24`)

## The installation of K8s cluster

## The installation of private Docker registry

## The installation of Prometheus 

Optionally, you can install node exporters for getting metrics about the host.


## Port forwarding for public-facing services
