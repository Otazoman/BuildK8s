#/bin/bash

CMDNAME=`basename $0`

if [ $# -ne 5 ]; then
  echo "Usage: ${CMDNAME} nodetype priority password virtualip lb1ip lb2ip " 1>&2
  exit 1
fi

ROUTERID=10
PRIORITY=$1  # keepalived priority param
PASSWD=$2    # keepalived password
VIP=$3       # virtual ip
LBIP_1=$4    # loadbarancer1 ip
LBIP_2=$5    # loadbarancer2 ip

IPADDR1=$KUBERMASTER1IP
IPADDR2=$KUBERMASTER1IP
IPADDR3=$KUBERMASTER1IP
PORT=6443

# Setting VIP & install
echo "net.ipv4.ip_nonlocal_bind = 1" | sudo tee -a /etc/sysctl.conf
sudo apt-get -y update
sudo apt-get -y install keepalived nginx

# Setting keepalived

sudo tee /etc/keepalived/check_haproxy.sh <<EOF
#!/bin/sh

if ! nc -z -w 3 localhost 6443
  then
  echo "Port 6443 is not available." 1>&2
  exit 1
fi

if ip address show secondary | grep -q ${VIP}
  then
  if ! curl --silent --max-time 2 --insecure https://${VIP}:6443/ -o /dev/null
    then
    echo "https://${VIP}:6443/ is not available." 1>&2
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
        ${LBIP_1}
        ${LBIP_2}
    }
    virtual_ipaddress {
        ${VIP}
    }
    track_script {
        check_haproxy
    }
}
EOF
sudo service keepalived restart

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
    bind *:6443
    mode tcp
    option tcplog
    default_backend apiserver

backend apiserver
    option httpchk GET /healthz
    http-check expect status 200
    mode tcp
    option ssl-hello-chk
    balance roundrobin
      server api-server1 ${IPADDR1}:${PORT} check
      server api-server2 ${IPADDR2}:${PORT} check
      server api-server3 ${IPADDR3}:${PORT} check
EOF

sudo useradd --system --no-create-home --shell=/sbin/nologin node
sudo systemctl restart haproxy
