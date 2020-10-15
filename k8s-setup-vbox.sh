# setup a centos7 base VM with a regular user, docker, kubernetes packages
# vCPU count to be 2 or more for kube master
baseVM=cent7bare
echo "192.168.1.87	cent7bare" | sudo tee -a /etc/hosts
user=dave

# Allow $user to be sudo
ssh root@$baseVM "useradd $user; usermod -aG wheel $user"
 
function setup_ssh() {
  # SSH access setup from desktop to the VMs for easy access"
  node=$1
  user=$2
  ssh $user@$node "mkdir .ssh; chmod 700 .ssh"
  cat ~/.ssh/id_rsa.pub | ssh $user@$node "cat - >> ~/.ssh/authorized_keys"
}
setup_ssh $baseVM $user

# do a full clone of $baseVM through vbox GUI
# find the IP and decide on the host name
# names are k8sm - for master, k8sn1 for minion 1, k8sn2 for minion2 and so on

function adjustHostname() {
  echo "After cloning run this function with new hostname and IP of the node"
  newHost=$1
  newIP=$2
  echo "$newIP	$newHost" | sudo tee -a /etc/hosts
  ssh root@$newIP <<EOF
    echo $newHost >> /etc/hostname
    echo HOSTNAME=$newHost >> /etc/sysconfig/network
    hostnamectl set-hostname $newHost
    reboot; reboot
EOF
  #echo "alias $newHost='ssh root@$newHost'" >> ~/.bashrc
}

# without below setup, minion won't pass preflight-check
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

common_pkgs="bzip2 wget docker"
sudo yum update -y
sudo yum install -y $common_pkgs

# setup repo for kubernetes for a Linux distribution with below info
# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

KUBE_VER=1.19.2-0

function yum_install_kube() {
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

  # Set SELinux in permissive mode (effectively disabling it)
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

  #sudo yum install -y kubeadm-$KUBE_VER kubelet-$KUBE_VER kubectl-$KUBE_VER 
  sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
}

function setup_firewalld() {
  # need to open 6443/tcp and 10250/tcp with firewalld so that minions can join
  sudo firewall-cmd --permanent --add-port=6443/tcp
  sudo firewall-cmd --permanent --add-port=10250/tcp
  sudo firewall-cmd --reload
  sudo firewall-cmd --list-ports

  # easier to disable firewalld while learning commands
  sudo systemctl stop firewalld
  sudo systemctl disable firewalld
}

function setup_k8s_common() {
  # Initialize kubernetes control plane - docker service needs to be running at this time
  # Note: the VM needs 2 vCPU

  sudo swapoff -a

  sudo systemctl start docker.service
  sudo systemctl enable docker.service

  sudo systemctl enable --now kubelet
}

function setup_master() {
  setup_k8s_common
  sudo kubeadm init --kubernetes-version 1.19.2 --pod-network-cidr 192.168.0.0/16
}
setup_master | tee $HOME/kubeadm-init.out

function setup_pod_network() {
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

#You should now deploy a pod network to the cluster.
#Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
#  https://kubernetes.io/docs/concepts/cluster-administration/addons/
# become a normal user - install calico
  wget https://docs.projectcalico.org/manifests/calico.yaml

  kubectl apply -f calico.yaml   # Note: this is being run as regular user
}

function setup_minion() {
  minion_node=$1
  echo "Clone minion from cent7bare - already has docker, kubeadm, kubelet etc installed"
  echo 'Find out IP of the $minion_node'
  echo 'adjustHostname $minion_node $minion_IP'
  echo 'ssh $minion_node'
  echo 'In minion_node: '
  echo 'setup_k8s_common'
  echo 'Find the kubeadm join command from $HOME/kubeadm-init.out and execute'
}

function k8s_yank() {
  sudo docker rm `docker ps -a -q`
  sudo docker rmi `docker images -q`
  sudo kubeadm reset 
  sudo yum remove kubeadm kubectl kubelet kubernetes-cni kube*    
  sudo yum autoremove 
  sudo rm -rf ~/.kube
}

function rm_master_taint() {
  echo "Taint is as below currently"
  kubectl describe nodes | grep -i Taint
: '
Taints:             node-role.kubernetes.io/master:NoSchedule
Taints:             <none>
'
  
  echo "Removing taint NoSchedule for master"
  # kubectl taint nodes --all node-role.kubernetes.io/master-
  kubectl taint nodes k8sm node-role.kubernetes.io/master-

  kubectl describe nodes | grep -i Taint

  echo "To restore the taint - as below"
  echo "kubectl taint nodes k8sm node-role.kubernetes.io/master:NoSchedule"
} 

function kube_autocomplete() {
  # Add autocomplete and an alias to .bashrc
  cat << EOF >> ~/.bashrc
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
alias kg='k get'
EOF
}


function various_cmds() {
  # to tail logs from a container

}

