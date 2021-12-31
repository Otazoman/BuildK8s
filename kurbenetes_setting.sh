#/bin/bash

USER=$(echo ${SUDO_USER:-$USER})
UID=$(echo ${SUDO_UID:-$SUDO_UID})
GID=$(echo ${SUDO_GID:-$SUDO_GID})
HOME=/home/${USER}
CMDNAME=`basename $0`

if [ $# -ne 10 ]; then
  echo "Usage: ${CMDNAME} please input args " 1>&2
  exit 1
fi

NODETYPE=$1    # nodetype
LBIP=$2        # loadbarancer virtual ip
LBNAME=$3      # loadbarancer virtual hostname
MASTERNAME1=$4 # kubernetes node1 hostname
MASTERNAME2=$5 # kubernetes node2 hostname
MASTERNAME3=$6 # kubernetes node3 hostname
DOMAIN=$7      # domain
KUBERIP1=$8    # kubernetes node1 ip
KUBERIP2=$9    # kubernetes node2 ip
KUBERIP3=$10   # kubernetes node3 ip
PORT=6443

# Added hosts
echo "${LBIP} ${LBNAME} ${LBNAME}.${DOMAIN}" | sudo tee -a /etc/hosts
echo "${KUBERIP1} ${MASTERNAME1} ${MASTERNAME1}.${DOMAIN}" | sudo tee -a /etc/hosts
echo "${KUBERIP2} ${MASTERNAME2} ${MASTERNAME2}.${DOMAIN}" | sudo tee -a /etc/hosts
echo "${KUBERIP3} ${MASTERNAME3} ${MASTERNAME3}.${DOMAIN}" | sudo tee -a /etc/hosts

# Check the following site to find out the latest version of Kubernetes.
# https://kubernetes.io/releases/notes/
OS=xUbuntu_20.04
VERSION=1.22
NETWORK=10.1.0.0/16

# Setting CRI-O
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${OS}/ /" | sudo tee -a /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${VERSION}/${OS}/ /"  | sudo tee -a /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:${VERSION}.list
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:${VERSION}/${OS}/Release.key | sudo apt-key add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/${OS}/Release.key | sudo apt-key add -

sudo apt-get -y update
sudo apt-get install -y cri-o cri-o-runc

sudo systemctl daemon-reload
sudo systemctl start crio
sudo systemctl enable crio

# Install kubeadm
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl cri-o cri-o-runc

# Setting kubeadm
echo 'KUBELET_EXTRA_ARGS=--cgroup-driver=systemd --container-runtime=remote --container-runtime-endpoint="unix:///var/run/crio/crio.sock"' | sudo tee /etc/default/kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Setting Main Node
SLEEP_TIME=30
mkdir -p ${HOME}/.kube
if [ "$NODETYPE" = "cluster" ]; then
  curl https://docs.projectcalico.org/manifests/calico.yaml -O
  cp -ap calico.yaml calico.yaml.org
  sed -i -e "s?192.168.0.0/16?${NETWORK}?g" calico.yaml
  sudo kubeadm init --cri-socket /var/run/crio/crio.sock --control-plane-endpoint "${LBNAME}:${PORT}" --upload-certs --pod-network-cidr=${NETWORK}
  sudo cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config
  sudo chown ${UID}:${GID} ${HOME}/.kube/config
  kubectl apply -f calico.yaml
  while true
  do
    echo " Please wait node setting "
    sleep ${SLEEP_TIME}
    kubectl get nodes | grep Ready
    if [ $? = 0 ]; then
      kubectl taint nodes --all node-role.kubernetes.io/master:NoSchedule-
      kubectl describe nodes | grep Taints
      break
    fi
  done
  kubectl get nodes
fi
if [ "$NODETYPE" = "nocluster" ]; then
  curl https://docs.projectcalico.org/manifests/calico.yaml -O
  cp -ap calico.yaml calico.yaml.org
  sed -i -e "s?192.168.0.0/16?${NETWORK}?g" calico.yaml
  sudo kubeadm init --cri-socket /var/run/crio/crio.sock --node-name ${MASTERNAME1}.${DOMAIN} --pod-network-cidr=${NETWORK}
  sudo cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config
  sudo chown ${UID}:${GID} ${HOME}/.kube/config
  kubectl apply -f calico.yaml
  while true
  do
    echo " Please wait node setting "
    sleep ${SLEEP_TIME}
    kubectl get nodes | grep Ready
    if [ $? = 0 ]; then
      kubectl taint nodes --all node-role.kubernetes.io/master:NoSchedule-
      kubectl describe nodes | grep Taints
      break
    fi
  done
  kubectl get nodes
fi

rm -rf previous_setting.sh
rm -rf kurbenetes_setting.sh
