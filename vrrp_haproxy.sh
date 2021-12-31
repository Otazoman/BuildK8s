#/bin/bash

CMDNAME=`basename $0`

if [ $# -ne 16 ]; then
  echo "Usage: ${CMDNAME} please input args " 1>&2
  exit 1
fi

ROUTERID=$1     # Routerid Caution number only
PRIORITY=$2     # Keepalived priolity
PASSWD=$3       # Keepalived password
LB1_NAME=$4     # loadbarancer1 hostname
LB2_NAME=$5     # loadbarancer2 hostname
LB1_IP=$6       # loadbarancer1 ip
LB2_IP=$7       # loadbarancer2 ip
LBNAME=$8       # Keepalived virtual hostname
LBIP=$9         # Keepalived virtual ip
MASTERNAME1=$10 # kubernetes node1 hostname
MASTERNAME2=$11 # kubernetes node2 hostname
MASTERNAME3=$12 # kubernetes node3 hostname
DOMAIN=$13      # domain
KUBERIP1=$14    # kubernetes node1 ip
KUBERIP2=$15    # kubernetes node2 ip
KUBERIP3=$16    # kubernetes node3 ip
PORT=6443

# Added hosts
echo "${LBIP} ${LBNAME} ${LBNAME}.${DOMAIN}" | sudo tee -a /etc/hosts
echo "${LB1_IP} ${LB1_NAME} ${LB1_NAME}.${DOMAIN}" | sudo tee -a /etc/hosts
echo "${LB2_IP} ${LB1_NAME} ${LB2_NAME}.${DOMAIN}" | sudo tee -a /etc/hosts
echo "${KUBERIP1} ${MASTERNAME1} ${MASTERNAME1}.${DOMAIN}" | sudo tee -a /etc/hosts
echo "${KUBERIP2} ${MASTERNAME2} ${MASTERNAME2}.${DOMAIN}" | sudo tee -a /etc/hosts
echo "${KUBERIP3} ${MASTERNAME3} ${MASTERNAME3}.${DOMAIN}" | sudo tee -a /etc/hosts

# Setting VIP & install
echo "net.ipv4.ip_nonlocal_bind = 1" | sudo tee -a /etc/sysctl.conf
sudo apt-get -y update
sudo apt-get -y install keepalived

# Setting keepalived
sudo tee /etc/keepalived/check_haproxy.sh <<EOF
#!/bin/sh

if ! nc -z -w 3 localhost ${PORT}
  then
  echo "Port 6443 is not available." 1>&2
  exit 1
fi

if ip address show secondary | grep -q ${LBNAME}
  then
  if ! curl --silent --max-time 2 --insecure https://${LBNAME}:6443/ -o /dev/null
    then
    echo "https://${LBNAME}:6443/ is not available." 1>&2
    exit 1
  fi
fi
EOF
sudo chmod 755 /etc/keepalived/check_haproxy.sh

sudo tee /etc/keepalived/keepalived.conf <<EOF
global_defs {
    vrrp_garp_master_refresh 60
}
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id ${ROUTERID}
    priority ${PRIORITY}
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass ${PASSWD}
    }
    unicast_peer {
        ${LB1_IP}
        ${LB2_IP}
    }
    virtual_ipaddress {
        ${LBIP}
    }
    track_script {
        check_haproxy
    }
}
EOF
sudo service keepalived restart

# Setting haproxy
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:vbernat/haproxy-2.3
sudo apt update
sudo apt -y install haproxy

# Setting ha-proxy
sudo tee /etc/haproxy/haproxy.cfg <<EOF
global
        log /dev/log    local0
        log /dev/log    local1 notice
        user haproxy
        group haproxy
        daemon

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 1
    timeout http-request    10s
    timeout queue           20s
    timeout connect         5s
    timeout client          20s
    timeout server          20s
    timeout http-keep-alive 10s
    timeout check           10s

frontend apiserver
    bind *:${PORT}
    mode tcp
    option tcplog
    default_backend apiserver

backend apiserver
    option httpchk GET /healthz
    http-check expect status 200
    mode tcp
    option ssl-hello-chk
    balance roundrobin
      server api-server1 ${MASTERNAME1}:${PORT} check
      server api-server2 ${MASTERNAME2}:${PORT} check
      server api-server3 ${MASTERNAME3}:${PORT} check
EOF

sudo useradd --system --no-create-home --shell=/sbin/nologin node
sudo systemctl restart haproxy

rm -rf previous_setting.sh
rm -rf vrrp_haproxy.sh
