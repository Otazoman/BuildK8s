#bin/bash

CMDNAME=`basename $0`

if [ $# -ne 7 ]; then
  echo "Usage: ${CMDNAME} networkaddress glusterpath lb1 lb2 nodetype" 1>&2
  exit 1
fi

NODETYPE=$1    # Gluster NodeType
NETWORK=$2     # Setting CIDR
GLUSTERPATH=$3 # glusterfs mount path
SUBPATH=$4     # glusterfs directory path
VOLUMENAME=$5  # glusterfs volumename
LB1_NAME=$6    # loadbarancer1 hostname
LB2_NAME=$7    # loadbarancer2 hostname

#Open fireWall
sudo ufw allow from ${NETWORK} to any port 111
sudo ufw allow from ${NETWORK} to any port 2409
sudo ufw allow from ${NETWORK} to any proto tcp port 24007:24020
sudo ufw allow from ${NETWORK} to any proto tcp port 38465:38490
sudo ufw allow from ${NETWORK} to any proto tcp port 49152:49199

#Gluster Install
sudo apt -y install glusterfs-server
sudo systemctl enable glusterd
sudo systemctl start glusterd

cd /
sudo mkdir -p /${GLUSTERPATH}
sudo mkdir -p /${GLUSTERPATH}/${SUBPATH}
GFPATH=/${GLUSTERPATH}/${SUBPATH}

if [ "$NODETYPE" = "primary" ]; then
    sudo gluster peer probe ${LB2_NAME}
    sudo gluster peer status | grep Uuid
    if [ $? = 0 ]; then
       sleep 30
       sudo gluster volume create ${VOLUMENAME} replica 2 transport tcp ${LB1_NAME}:${GFPATH} ${LB2_NAME}:${GFPATH} force
    fi
    sudo sudo gluster vol info | grep ${VOLUMENAME}
    if [ $? = 0 ]; then
       sudo gluster volume start ${VOLUMENAME}
    fi
fi

# mount glusterfs
sudo mkdir -p /mnt/${VOLUMENAME}
echo "# glustervolume" | sudo tee -a /etc/fstab
echo "${LB1_NAME}:/${VOLUMENAME} /mnt/${VOLUMENAME} glusterfs defaults,_netdev,backupvolfile-server=${LB2_NAME} 1 2" | sudo tee -a /etc/fstab
