#bin/bash

CMDNAME=`basename $0`
if [ $# -lt 7 ]; then
  echo "Usage: ${CMDNAME} nodetype networkaddress path bricksname volume_name host1 host2 host3" 1>&2
  exit 1
fi

NODETYPE=$1             # Gluster NodeType
NETWORK=$2              # Setting CIDR
GLUSTERPATH=$3          # glusterfs mount path
SUBPATH=$4              # glusterfs directory path
VOLUMENAME=$5           # glusterfs volumename
HOST_NAME=("${@:6}")    # hostname args

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
sudo mkdir -p ${SUBPATH}
GFPATH=/${GLUSTERPATH}/${SUBPATH}


PATHSTR=""
if [ "$NODETYPE" = "primary" ]; then
   for H in "${HOST_NAME[@]}"
   do
       sudo gluster peer probe ${H}
       PATHSTR+="${H}:${GFPATH} "
   done
   REPRICA=${#HOST_NAME[*]}
   sudo gluster peer status | grep Uuid
   if [ $? = 0 ]; then
      sleep 30
      sudo gluster volume create ${VOLUMENAME} replica ${REPRICA} transport tcp ${PATHSTR} force
   fi
   sudo gluster vol info | grep ${VOLUMENAME}
   if [ $? = 0 ]; then
      sudo gluster volume start ${VOLUMENAME}
   fi
fi

# mount glusterfs
sudo mkdir -p /mnt/${VOLUMENAME}
echo "# glustervolume" | sudo tee -a /etc/fstab
echo "${HOST_NAME[0]}:/${VOLUMENAME} /mnt/${VOLUMENAME} glusterfs defaults,_netdev,backupvolfile-server=${HOST_NAME[1]}:${HOST_NAME[2]} 1 2" | sudo tee -a /etc/fstab
