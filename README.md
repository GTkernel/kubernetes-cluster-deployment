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

**NOTE** For Ubuntu, please stop `systemd-resolved` first to prevent it affect the K8s DNS policy, because kubeadm detects it and adjuests kubelet automatically.

- Only master node has the public IP, in-cluster communication goes through private network (e.g. `192.168.1.0/24`).
- Clusters are set with NAT and NFS, so the worker nodes can access public traffic, and configuration files are sharable.
- For any configuration template, you may check and change it to fit your environment.

- Please make sure **Docker** engine on every host, and additionally, [helm](https://helm.sh/docs/intro/install/) on master.

## The installation of K8s cluster

Kubernetes v1.24 officially [removes dockershim](https://kubernetes.io/blog/2022/01/07/kubernetes-is-moving-on-from-dockershim/).
For the best familiarity of our operations, we still use Docker as container runtime. 
However, we still face issues with the integration of `cri-dockerd` and Cilium. 
So currently, we only verified Kubernetes v1.25.0 with WeaveNet as the CNI.
If you prefer to install other CNIs, you would need to verify the network settings or just downgrade Kubernetes installation to **v1.23**.

#### 0. Install Docker on every node, and CRI if required

The Docker version I used is **1.5**.

Next, if you plan to install Kubernetes with version higher than v1.23, you will need to install container runtime interface (CRI).
Here, we follow the official instruction of cri-dockerd. Please refer to its [README](https://github.com/Mirantis/cri-dockerd) for the installation.


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
$ sudo apt-get install kubelet=1.23.6-00 kubeadm=1.23.6-00 kubectl=1.23.6-00
```

  For worker node:
```
$ sudo apt-get install kubelet=1.23.6-00 kubeadm=1.23.6-00
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
Also, put/update `pre-kubeadm/kubelet_v1_23.yaml` to the exact path of `$PATH_OF_YOUR_KUBELET_CONF_YAML`.

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

Specify the node's private ip as following: (skip this if you want to communicate nodes by public IP)
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

[//]: <> (**TIPS:** For anytime you want to restart the daemons, had better following the order of this: 
docker, cri-docker, then kubelet.)

#### 4. Start K8s master node

Here, I choose to use Cilium agent's functionality to replace **kube-proxy**. 
If you want to keep **kube-proxy**, you don't need to add the flag `--skip-phases=addon/kube-proxy`.
If you want to use master's public IP for in-cluster communication, bypass the flag `--apiserver-advertise-address`.
Here, we configure K8s networking CIDR to prevent conflicts of CNI default settings and our host private network (e.g. `K8S_NETWORK_CIDR=10.0.0.0/16`).

```
$ sudo kubeadm init --ignore-preflight-errors=Swap --apiserver-advertise-address=$MASTER_PRIVATE_IP --skip-phases=addon/kube-proxy --pod-network-cidr=$K8S_NETWORK_CIDR
```
Or, for v1.24 or higher version Kubernetes, need to add the tag `--cri-socket`. 

```
$ sudo kubeadm init --ignore-preflight-errors=Swap --apiserver-advertise-address=$MASTER_PRIVATE_IP --cri-socket=unix:///var/run/cri-dockerd.sock
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
#### 5. Install CNI -- Calico

**NOTE:** There are several [CNI solutions](https://github.com/containernetworking/cni) you can play with, no necessary to stick to Calico only.

We refer to the [official tutorial](https://projectcalico.docs.tigera.io/getting-started/kubernetes/self-managed-onprem/onpremises) for Calico setup for the personal cluster.

Create Calico components by following command on master node:

```
$ kubectl create -f cni/calico_v3_23_2.yaml
```

Then, you can check the starting status as following:

```
$ kubectl get pod -n kube-system
NAME                                       READY   STATUS              RESTARTS   AGE
calico-kube-controllers-7bc6547ffb-bgxb4   1/1     Running             0          30s
calico-node-wp8dz                          1/1     Running             0          30s
coredns-64897985d-fm7fj                    0/1     ContainerCreating   0          2m54s
coredns-64897985d-nj6m4                    0/1     ContainerCreating   0          2m54s
etcd-gabbro                                1/1     Running             8          3m7s
kube-apiserver-gabbro                      1/1     Running             1          3m7s
kube-controller-manager-gabbro             1/1     Running             1          3m7s
kube-proxy-jxpsn                           1/1     Running             0          2m54s
kube-proxy-pg2q2                           1/1     Running             0          117s
kube-scheduler-gabbro                      1/1     Running             1          3m7s
```

It is correct that CoreDNS is in `ContainerCreating` state, because it needs to wait any worker node to be ready.
Check it again after you add other node in cluster.

Still, if your networking environment is like ours, having several IP/CIDR on host, you would need to specify the primary K8s node IP for configuring BGP.

```
$ kubectl set env daemonset/calico-node -n kube-system IP_AUTODETECTION_METHOD=kubernetes-internal-ip
```

#### 5. Install CNI -- Cilium

**NOTE:** There are several [CNI solutions](https://github.com/containernetworking/cni) you can play with, no necessary to stick to Cilium only.

On master node, run following script to install Cilium.

**NOTE AGAIN:** If you want to keep **kube-proxy**, remove the parameter `--set kubeProxyReplacement=strict` in the file, `cni/cilium_v1_11_4.sh`, 
before you run it.
```
$ sh cni/cilium_v1_11_4.sh
```

After you successfully run the Cilium installation by helm, your control plane would looks similar as following (in case of without **kube-proxy**):

```
$ kubectl get pod -n kube-system
NAME                              READY   STATUS    RESTARTS   AGE
cilium-6dj4n                      1/1     Running   0          40s
cilium-operator-f4c69945c-2lntd   1/1     Running   0          40s
cilium-operator-f4c69945c-f2jpv   0/1     Pending   0          40s
coredns-64897985d-6kn5r           1/1     Running   0          3m6s
coredns-64897985d-kzbtq           1/1     Running   0          3m6s
etcd-granite                      1/1     Running   0          3m11s
kube-apiserver-granite            1/1     Running   0          3m12s
kube-controller-manager-granite   1/1     Running   0          3m11s
kube-scheduler-granite            1/1     Running   0          3m10s
```

Let's verify the Cilium's setup status:

```
$ kubectl exec -it -n kube-system cilium-6dj4n -- cilium status
Defaulted container "cilium-agent" out of: cilium-agent, mount-cgroup (init), clean-cilium-state (init)
KVStore:                Ok   Disabled
Kubernetes:             Ok   1.23 (v1.23.6) [linux/amd64]
Kubernetes APIs:        ["cilium/v2::CiliumClusterwideNetworkPolicy", "cilium/v2::CiliumEndpoint", "cilium/v2::CiliumNetworkPolicy", "cilium/v2::CiliumNode", "core/v1::Namespace", "core/v1::Node", "core/v1::Pods", "core/v1::Service", "discovery/v1::EndpointSlice", "networking.k8s.io/v1::NetworkPolicy"]
KubeProxyReplacement:   Strict   [eno1 192.168.1.191 (Direct Routing)]
Host firewall:          Disabled
Cilium:                 Ok   1.11.4 (v1.11.4-9d25463)
NodeMonitor:            Listening for events on 8 CPUs with 64x4096 of shared memory
Cilium health daemon:   Ok
IPAM:                   IPv4: 4/254 allocated from 10.0.0.0/24,
BandwidthManager:       Disabled
Host Routing:           Legacy
Masquerading:           IPTables [IPv4: Enabled, IPv6: Disabled]
Controller Status:      32/32 healthy
Proxy Status:           OK, ip 10.0.0.119, 0 redirects active on ports 10000-20000
Hubble:                 Ok   Current/Max Flows: 849/4095 (20.73%), Flows/s: 3.14   Metrics: Disabled
Encryption:             Disabled
Cluster health:         1/1 reachable   (2022-05-16T04:35:13Z)
```

It showes Cilium agent (on master node) is functional with proxy support. 

#### 5. Install CNI -- WeaveNet

Create WeaveNet components by following command on master node:

```
$ kubectl create -f cni/weavenet_v2_8_1.yml
```

#### 6. Join K8s worker node

To add worker nodes in cluster, fire this join command, which covers part of the one we copid at step 4.

```
$ sudo kubeadm join $MASTER_IP:6443 --token $TOKEN --discovery-token-ca-cert-hash $SHA256_CERT --ignore-preflight-errors=Swap 
```

#### 7. Verify the cluster 

Now, you can check if your nodes are all shown "Ready" on master node:

```
$ kubectl get node
```

#### 8. Untaint control plane nodes  

Optionally, you can choose to get control plane nodes to be scheduled with general applications.

```
$ kubectl taint nodes --all node-role.kubernetes.io/control-plane node-role.kubernetes.io/master-
```

#### 9. Join worker node after kubeadm token is expired

The token of kubeadm will be expired after 24h. 
If you want to add new work node after that period, you need to create a new one, and join your new worker with it.

```
// on master node
$ sudo kubeadm token create
$NEW_TOKEN

// you can check it shown on the list
$ sudo kubeadm token list

```
Then, you use the token just created on the new worker.

```
// on worker node
$ sudo kubeadm join $MASTER_IP:6443 --token $NEW_TOKEN --ignore-preflight-errors=Swap --discovery-token-unsafe-skip-ca-verification
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
```
$ kubectl create -f docker-registry/pvc.yaml
```

#### 3. Create the Secret for authentication
```
$ mkdir secrets

$ openssl req -newkey rsa:4096 -nodes -sha256 -keyout secrets/domain.key -x509 -days 365 -out secrets/domain.crt

$ openssl rand -hex -out secrets/http.secret 8

$ docker run -i httpd /bin/bash -c 'echo $PASSWORD | /usr/local/apache2/bin/htpasswd -nBi $USER_NAME' > secrets/registry_passwd

$ kubectl create secret generic registry-secrets --from-file secrets/
```

#### 4. Create the registry Deployment and Service
```
$ kubectl create -f docker-registry/registry.yaml
```

#### 5. Login registry on every node

First, we need to copy public key to every node.
Public key is the one `./secrets/domain.crt` generated by step 3.

```
// Copy public to the directory of certificates in system side
$ ls /usr/local/share/ca-certificates
domain.crt

$ sudo update-ca-certificates

$ sudo systemctl restart docker
```
Now, you can login the private registry with the basic authentication specified in step 3: `$USER_NAME` and `$PASSWORD`.

```
$ docker login $MASTER_HOSTNAME:30500
```

**TIPS:** If you get following message when runnging `docker login`,

```
x509: certificate relies on legacy Common Name field, use SANs or temporarily enable Common Name matching with GODEBUG=x509ignoreCN=0
```
add this flag `-addext "subjectAltName = DNS:$MASTER_HOSTNAME"` when you create `domain.crt`.


## The installation of Prometheus 

Optionally, you can install node exporters for getting metrics about the host. 
The deployment config files are under `./prometheus`

#### 1. Create namespace, monitoring

```
$ kubectl create -f prometheus/namespace.yaml
```

#### 2. Deploy service configuration of Prometheus

```
$ kubectl create -f prometheus/config/k8s.yaml
```

#### 3. Deploy other resources, including the container of Prometheus

This command would deploy all resources under the directory.

```
$ kubectl create -f prometheus/deploy/
```

#### 4. Optionally, deploy the node exporter for host metrics

```
$ kubectl create -f prometheus/node-exporter/node-exporter.yaml
```


#### 5. Verify the deployment 

```
$ kubectl get pod -n monitoring
NAME                          READY   STATUS    RESTARTS   AGE
node-exporter-4jdzz           1/1     Running   0          6s
node-exporter-hnggh           1/1     Running   0          6s
node-exporter-kvlfj           1/1     Running   0          6s
node-exporter-nzqq6           1/1     Running   0          6s
prometheus-6dbf95cb45-5nc8d   1/1     Running   0          63s

$ kubectl get service -n monitoring
NAME             TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
prometheus-svc   NodePort   10.109.166.156   <none>        9090:32351/TCP   5m11s

$ curl localhost:32351
<a href="/graph">Found</a>.
```
If your K8s networking is on private CIDR like our setup, to access the webUI of Prometheus
by browser, you would need to do IP forwarding (next section).
Otherwise, you can access any public IP of the cluster with the port, 32351, in this case.


## Port forwarding for public-facing services

As mentioned in the section of environement specification, my cluster only has on public IP on master,
other nodes only has private IP.

For building NAT, you can run the script `./port-forwarding/nat_rule.sh` on master. 
It helps to create a virtual NIC with private IP, and the rules to forward the egress traffic of worker nodes to Internet.

On the other hand, while K8s cluster networking is built on private network,
to expose certain K8s Service, we need to forward the traffic between public NIC/IP and private NIC/IP by ourselves 
(CNI doesn't manage host network for sure).

Therefore, I prepare the other script `./port-forwarding/service_forward.sh`.
Like the Prometheus case mentioned in last section, you would need to add parameters like below:

```
#!/bin/bash

NPORT=32351
CPORT=9090
HOST_PIP=$ANY_WORKER_IP
```
After running it on master, you can access Prometheus's webUI through the master's public IP with node port 32351.
