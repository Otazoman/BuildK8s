# Build K8s  
ShellScript to build HA-PROXY and Kubernetes  
  
# Description.  
This is a shell script to build a master and sub environment for kubernetes, using CRI-O and Calico.
You can switch between clustered and non-clustered configurations with command line options.
It is recommended that you also run the HA-PROXY build Shell if you are using a clustered configuration.  
As a bonus, we have also prepared a shell script that can build GlusterFS on a HAProxy server in a two-unit configuration.  
  
# Operating environment  
Ubuntu 20.04.3 LTS  

# How to use  
$ git clone https://github.com/Otazoman/BuildK8s.git  
$ cd BuildK8s  
  
## Common setting  
### HA-PROXY  
$ sudo . /previous_setting.sh 192.168.0.11 192.168.0.1 lb1srv yourdomain on  
$ sudo . /previous_setting.sh 192.168.0.12 192.168.0.1 lb2srv yourdomain on  
### Kubernetes  
$ sudo . /previous_setting.sh 192.168.0.21 192.168.0.1 kube1srv yourdomain off  
$ sudo . /previous_setting.sh 192.168.0.22 192.168.0.1 kube2srv yourdomain off  
$ sudo . /previous_setting.sh 192.168.0.23 192.168.0.1 kube3srv yourdomain off    
## Build HA-Proxy(After executing the common shell script)  
### Main  
$ sudo ./vrrp_haproxy.sh \  
	100 \  
	150 \  
	password \  
	lb1srv \  
	lb2srv \  
	192.168.0.11 \  
	192.168.0.12 \  
	halbsrv \  
	192.168.0.10 \  
	kube1srv \  
	kube2srv \  
	kube3srv \  
	yourdomain \  
	192.168.0.21 \  
	192.168.0.22 \  
	192.168.0.23  
### Sub
$ sudo ./vrrp_haproxy.sh \  
	100 \  
	100 \  
	password \  
	lb1srv \  
	lb2srv \  
	192.168.0.11 \  
	192.168.0.12 \  
	halbsrv \  
	192.168.0.10 \  
	kube1srv \  
	kube2srv \  
	kube3srv \  
	yourdomain \  
	192.168.0.21 \  
	192.168.0.22 \  
	192.168.0.23  
## Build Kubernetes(After executing the common shell script)  
### Cluster master  
$ sudo ./kurbenetes_setting.sh \  
	cluster \  
	192.168.0.10 \  
	halbsrv \  
	kube1srv \  
	kube2srv \  
	kube3srv \  
	yourdomain \  
	192.168.0.21 \  
	192.168.0.22 \  
	192.168.0.23  
### Non cluster master  
$ sudo ./kurbenetes_setting.sh \  
	cluster \  
	192.168.0.10 \  
	halbsrv \  
	kube1srv \  
	kube2srv \  
	kube3srv \  
	yourdomain \  
	192.168.1.21 \  
	192.168.1.22 \  
	192.168.1.23  
### Sub node  
$ sudo ./kurbenetes_setting.sh \  
	sub \  
	192.168.1.10 \  
	halbsrv \  
	kube1srv \  
	kube2srv \  
	kube3srv \  
	yourdomain \  
	192.168.1.21 \  
	192.168.1.22 \  
	192.168.1.23  
## Build GlusterFS Cluster (After executing the HAProxy or kubernetes shell)  
### Run from subnodes  
$ sudo ./glusterfs.sh \  
	secondary \  
	192.168.0.0/24 \  
	gfs \  
	bricks \  
	volume \  
	lb1srv \  
	lb2srv  
### After subnodes mainnode execute  
$ sudo ./glusterfs.sh \
        primary \
        192.168.0.0/24 \
        gfs \
        bricks \
        volume \
        lb1srv \
        lb2srv  
 
*Caution  
In the case of subnodes, you need to submit the command after configuring the main machine (cri-socket option is required)  
ex)  
$ sudo kubeadm --cri-socket /var/run/crio/crio.sock join halbsrv:6443 --token hoge \  
        --discovery-token-ca-cert-hash sha256:fuga \
        --control-plane --certificate-key fuga  
$ mkdir -p ${HOME}/.kube  
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config  
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config  

