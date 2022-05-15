# Kubernetes Deployment for the Personal Cluster

## Introduction

This documentation/installation steps is for building a small, private, and research-facing Kubernetes cluster.
 
The most instructions refer to the [official document](https://kubernetes.io/docs/setup/).
For the setup of Docker registry and Prometheus, we refer to the book, [DevOps with Kubernetes](https://github.com/PacktPublishing/DevOps-with-Kubernetes-Second-Edition).

## Environment specification

Kubernetes is flexible with most of the environment, so it is not restricted to what we listed below.
It is recommended to check the alternative ways for what fit better in your own environment.

- Four nodes with Intel i7 (4 cores) and 32 GB RAM.
- Nodes are connected by 10 GB Ethernet switch.
- All nodes are **Ubuntu 18.04**.
- Only master node has the public IP, in-cluster communication goes through private network (e.g. `192.168.1.0/24`).
- Clusters are set with NAT and NFS, so the worker nodes can access public traffic, and configuration files are sharable.
- For any configuration template, you may check and change it to fit your environment.
- Please make sure **Docker** engine and **Go** are installed on every host, and additionally, **helm** on master.

## The installation of K8s cluster

We install the Kubernetes v1.24, which officially [removes dockershim](https://kubernetes.io/blog/2022/01/07/kubernetes-is-moving-on-from-dockershim/).
For the best familiarity of our operations, we still use Docker as container runtime. 

#### 0. Install Docker and its CRI on every node

a) Install Docker on every node. The Docker version I used is **1.5**.

b) Install **cri-dockerd**

The installation steps here follows to the [official documentation](https://github.com/Mirantis/cri-dockerd).

First, build the code:

```
$ cd /tmp
$ git clone https://github.com/Mirantis/cri-dockerd
$ cd /tmp/cri-dockerd
$ mkdir bin
$ cd src && go get && go build -o ../bin/cri-dockerd
```

Next, run the scripts to install `cri-dockerd` with systemd:

```
$ sudo sh ./pre-kubeadm/install-cri.sh
```

#### 1. Install commands and daemon on every node

**NOTE:** The content here refers to the [official webpage](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/), please get the packages based on your Linux distribution.

a) Get public key of APT repository

```
$ sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
```

b) Update library

```
$ echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

$ sudo apt-get update
```

c) Install packages

Worker node doesn't require **kubectl** while we only send API calls from master. 

  For master node:
```
$ sudo apt-get install kubelet kubeadm kubectl
```

  For worker node:
```
$ sudo apt-get install kubelet kubeadm
```


#### 2. Setup configuration files for Kubelet

a) Check systemd parameters

```
$ sudo vim /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
```

In this systemd config file of **kubelet** for **kubeadm**,
we need to update/verify two parameters.
For the first one, add one line to specify the config file for kubelet:
```
:
Environment="KUBELET_CONFIG_ARGS=--config=$PATH_OF_YOUR_KUBELET_CONF_YAML"
:
```
Also, put/update `pre-kubeadm/kubelet_v1_24.yaml` to the exact path of `$PATH_OF_YOUR_KUBELET_CONF_YAML`.

For the second one, there is specified an additional environment file as following (should be already listed)
```
:
EnvironmentFile=-/etc/default/kubelet
:
```

Now, your systemd config file should look similar like `./pre-kubeadm/systemd_setup`.

b) Add the additional variable file for configuration

While nodes are connected by private networking, we need to specify private IP, 
separately on every node, in the environment file mentioned in last step.

Specify the node's private ip as following:
```
$ sudo vim /etc/default/kubelet

KUBELET_EXTRA_ARGS=--node-ip=$PRIVATE_IP
```


#### 3. Start Kubelet

Now you can start Kubelet daemon on every node.
```
$ sudo systemctl enable kubelet
$ sudo systemctl start kubelet
```

**TIPS:** For anytime you want to restart the daemons, had better following the order of this: 
docker, cri-docker, then kubelet. 

#### 4. Start K8s master node

Here, I choose to use Cilium agent's functionality to replace **kube-proxy**. 
If you want to keep **kube-proxy**, you don't need to add the flag `--skip-phases=addon/kube-proxy`

```
$ sudo kubeadm init --ignore-preflight-errors=Swap --apiserver-advertise-address=$MASTER_PRIVATE_IP --skip-phases=addon/kube-proxy --cri-socket unix:///var/run/cri-dockerd.sock 
```

**IMPORTANT:** Now, copy the last log shown on your screen, the line starts from `kubeadm join ...`.
This command has the credential (standing for 1 day by default) for the first handshake between master and worker. 
You will need it when setting up worker nodes.

Next, setup the command line interface on master for management and deployment.

```
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
``` 

#### 5. Install CNI -- Cilium

**NOTE:** There are several [CNI solutions](https://github.com/containernetworking/cni) you can play with, no necessary to stick to Cilium only.

On master node, run following script to install Cilium.
**NOTE AGAIN:** If you want to keep **kube-proxy**, remove the parameter `--set kubeProxyReplacement=strict` in the file, `cilium/helm_v1_11_4.sh`, 
before you run it.
```
$ sh cilium/helm_v1_11_4.sh
```

After you successfully run the Cilium installation by helm, your control plane would looks similar as following (in case of without **kube-proxy**):

```
$ kubectl get pod -n kube-system
NAME                              READY   STATUS    RESTARTS   AGE
cilium-n4n9d                      1/1     Running   0          119s
cilium-operator-8f8d6fdbc-2qk8n   0/1     Pending   0          119s
cilium-operator-8f8d6fdbc-6rs86   1/1     Running   0          119s
coredns-6d4b75cb6d-dvdd4          1/1     Running   0          26s
coredns-6d4b75cb6d-rg97c          1/1     Running   0          11s
etcd-granite                      1/1     Running   0          24m
kube-apiserver-granite            1/1     Running   0          24m
kube-controller-manager-granite   1/1     Running   0          24m
kube-scheduler-granite            1/1     Running   0          24m
```

Let's verify the Cilium's setup status:

```
$ kubectl exec -it -n kube-system cilium-n4n9d -- cilium status
Defaulted container "cilium-agent" out of: cilium-agent, mount-cgroup (init), clean-cilium-state (init)
KVStore:                Ok   Disabled
Kubernetes:             Ok   1.24 (v1.24.0) [linux/amd64]
Kubernetes APIs:        ["cilium/v2::CiliumClusterwideNetworkPolicy", "cilium/v2::CiliumEndpoint", "cilium/v2::CiliumNetworkPolicy", "cilium/v2::CiliumNode", "core/v1::Namespace", "core/v1::Node", "core/v1::Pods", "core/v1::Service", "discovery/v1::EndpointSlice", "networking.k8s.io/v1::NetworkPolicy"]
KubeProxyReplacement:   Strict   [eno1 $MASTER_PRIVATE_IP (Direct Routing)]
Host firewall:          Disabled
Cilium:                 Ok   1.11.4 (v1.11.4-9d25463)
NodeMonitor:            Listening for events on 8 CPUs with 64x4096 of shared memory
Cilium health daemon:   Ok
IPAM:                   IPv4: 2/254 allocated from 10.0.0.0/24,
BandwidthManager:       Disabled
Host Routing:           Legacy
Masquerading:           IPTables [IPv4: Enabled, IPv6: Disabled]
Controller Status:      24/24 healthy
Proxy Status:           OK, ip 10.0.0.119, 0 redirects active on ports 10000-20000
Hubble:                 Ok   Current/Max Flows: 674/4095 (16.46%), Flows/s: 0.20   Metrics: Disabled
Encryption:             Disabled
Cluster health:         1/1 reachable   (2022-05-15T17:27:48Z)
```
It showes Cilium agent (on master node) is functional with proxy support. 

#### 6. Join K8s worker node

To add worker nodes in cluster, fire this join command, which covers part of the one we copid at step 4.

```
$ sudo kubeadm join $MASTER_PRIVATE_IP:6443 --token $TOKEN --discovery-token-ca-cert-hash $SHA256_CERT --ignore-preflight-errors=Swap --cri-socket unix:///var/run/cri-dockerd.sock
```

#### 7. Verify the cluster 

Now, you can check if your nodes are all shown "Ready" on master node:

```
$ kubectl get node
```

## The installation of private Docker registry

Following steps work with the directory `./docker-registry`.

#### 1. Create the PresistentVolume (PV) on NFS

It is not necessary to build PV on a NFS mounting directoy.
However, the NFS PV is available for every node in cluster. You don't need to specify where to deploy the node based
on the location of directory of PV.
```
$ kubectl create -f docker-registry/nfs-pv.yaml
```

#### 2. Create the PresistentVolumeClaim (PVC) for registry container



#### 3. Create the registry Deployment and Service




## The installation of Prometheus 

Optionally, you can install node exporters for getting metrics about the host.


## Port forwarding for public-facing services
