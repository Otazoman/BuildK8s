# BuildK8s
Shell scripts for building kubernetes master and sub-environments  
  
# Description  
This is a shell script to build a Kubernetes environment by executing commands, using CRI-O and Calico.

# Operating environment  
Ubuntu 20.04.2 LTS  

# Usage  
$ sudo ./previous_setting.sh 192.168.0.100 192.168.0.1 kube-srv1 yourdomain.local  
Wait for reboot and reconnect terminal  
$ sudo ./kurbenetes_setting.sh master 192.168.0.100 kube-srv1 yourdomain.local  
For additional clusters, set "sub" instead of "main".

