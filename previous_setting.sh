#/bin/bash

CMDNAME=`basename $0`

if [ $# -ne 5 ]; then
  echo "Usage: ${CMDNAME} hostipadress gatewayip hostname domain" 1>&2
  exit 1
fi

HOSTIP=$1     # This host ip address
GATEWAYIP=$2  # Default gateway
HOSTNAME=$3   # This host hostname
DOMAIN=$4     # rhis host domain
SWAP=$5       # Swap mode
NETWORK=$(echo ${GATEWAYIP} | sed -e "s/\.\([^.]*\)$/.0\/24/")

## Firewall port open
sudo ufw allow from ${NETWORK} to any port 6443
sudo ufw allow from ${NETWORK} to any port 10250
sudo ufw allow from ${NETWORK} to any port 10251
sudo ufw allow from ${NETWORK} to any port 10252
sudo ufw allow from ${NETWORK} to any port 8080
sudo ufw allow from ${NETWORK} to any proto tcp port 2379:2380
sudo ufw allow from ${NETWORK} to any proto tcp port 30000:32767

## Replace ip addr
sudo cp /dev/null /etc/netplan/00-installer-config.yaml

sudo tee /etc/netplan/00-installer-config.yaml <<EOF
# This is the network config written by 'subiquity'
network:
  ethernets:
    eth0:
      addresses:
      - ${HOSTIP}/24
      gateway4: ${GATEWAYIP}
      nameservers:
        addresses:
        - 8.8.8.8
        - 8.8.4.4
  version: 2
EOF

## Set hostname
sudo hostnamectl set-hostname ${HOSTNAME}.${DOMAIN}
sudo cp /dev/null /etc/hosts
sudo tee /etc/hosts <<EOF
127.0.0.1 localhost
127.0.0.1 ${HOSTNAME} ${HOSTNAME}.${DOMAIN}
127.0.1.1 ${HOSTNAME}

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

## Update install package
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

## swap off (Only kubernetes hosts)
if [ "$SWAP" = "off" ]; then
  sudo swapoff -a
  sudo sed -i -e 's!/swap.img!#/swap.img!g' /etc/fstab
fi

## Reflect setting
echo " Close your terminal please "
sudo netplan apply
sudo shutdown -r now
