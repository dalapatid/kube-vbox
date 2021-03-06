# to become rrot in ubuntu
# sudo -i  or  sudo -s

function setup_common_tools() {
  sudo apt-get install -y vim wget curl unzip git

  # FIX vim for arrow keys
  echo "set nocompatible" >> ~/.vimrc
}

# FIX blank screen after suspend
sudo vim /etc/default/grub # then - GRUB_CMD_LINUX="nouveau.modeset=0"
# To suspend : power -> keep mouse pressed on Shutdown for pause icon -> press

# add the xps host IP for keeping backup
echo "192.168.1.218 dave-XPS xps" | sudo tee -a /etc/hosts

# need to enable root login over ssh
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd # need to restart for above to take effect

# add the ssh key to XPS and self for ansible test etc.
#cd; ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<<y 2>&1 > /dev/null
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
cat ~/.ssh/id_rsa.pub | ssh ${USER}@xps "cat >> ~/.ssh/authorized_keys"

# enable sshd
sudo apt install -y openssh-server
systemctl is-active sshd

# disable welcome messages on ssh login
sudo chmod -x /etc/update-motd.d/*

# FIX ubuntu freeze for NVIDIA driver and fan scream 
# Search for "Software & Updates" from applications menu (bottom left corber)
# Additional Drivers -> choose NVIDIA

# FIX chrome hang
# chrome://settings -> Advanced -> disable HW acceleration
# chrome://flags -> search GPU Rasterization -> disable

function setup_kvm() {
  # check for Intel VT-x(vmx) or AMD AMD-V(svm) capability
  grep -Eoc '(vmx|svm)' /proc/cpuinfo # gives available core count
  
  # To check for KVM capability
  sudo apt update
  sudo apt install -y cpu-checker
  kvm-ok
  
  # install KVM
  sudo apt install -y qemu-kvm libvirt-bin bridge-utils virtinst virt-manager
  
  # qemu-kvm - software that provides hardware emulation for the KVM hypervisor.
  # libvirt-bin - software for managing virtualization platforms.
  # bridge-utils - a set of command-line tools for configuring ethernet bridges.
  # virtinst - a set of command-line tools for creating virtual machines.
  # virt-manager provides an easy-to-use GUI interface and supporting command-line utilities for managing virtual machines through libvirt.
   
  sudo systemctl is-active libvirtd  # libvirtd starts automatically - verify
  
  # add $USER to appropriate groups for KVM
  sudo usermod -aG libvirt $USER
  sudo usermod -aG kvm $USER
  
  # a bridge device virbr0 was created from above install - good enough for creating VM
  # need to create a new bridge and configure for guest VMs to access outside
  # world through host interface
  #   https://help.ubuntu.com/community/KVM/Networking#Bridged_Networking
  
  # create VM from command line or through virt-manager - local-media, PXE, disk image etc.
  # worked fine for creating a Ubuntu VM
}

function setup_ansible() {
  # install and check ansible
  sudo apt install -y ansible
  ansible --version # by default 2.5.1 in ubuntu - need to update to 2.8
  sudo add-apt-repository ppa:ansible/ansible-2.8
  sudo apt-get update
  sudo apt install -y ansible
  ansible --version
  
  echo xps | sudo tee -a /etc/ansible/hosts 	# add the dave-XPS host for some ansible testing
  echo $(hostname) | sudo tee -a /etc/ansible/hosts # default inventory file - use -i option to specify a different file
  
  ansible $(hostname) -a /bin/date # to execute a command - $(hostanme) needs to be in /etc/ansible/hosts
  ansible $(hostname) -m ping # to run a module - give -i <inventory-file-path> and specify host group name in place of $(hostname)
  
  ansible all -m ping # to run command for all hosts - a host can 
  
  # NOTE: make sure in remote hosts, .ansible dir has the +wx permission for $USER - ran into .ansible owned by root in dave-XPS due to some prior testing.
  
  # in the /etc/ansible/hosts, host names could be specified as a pattern
  # www[01:50].example.com or www2[0:9].example.com 
  
  ansible all -m gather_facts --tree /tmp/facts  # available from 2.8, by default in ubuntu 2.5.1 - need to upgrade ansible
  
  # ansible has a check mode -C option - not all module provides
  # in playbook task with modules with no check mode will be skipped with -C option  - e.g. command module
}

function setup_terraform() {
  #TER_VER=`curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | grep tag_name | cut -d: -f2 | tr -d \"\,\v | awk '{$1=$1};1'`

  TER_VER=0.12.26
  echo "Installing terraform version $TER_VER"

  cd
  wget https://releases.hashicorp.com/terraform/${TER_VER}/terraform_${TER_VER}_linux_amd64.zip
  unzip terraform_${TER_VER}_linux_amd64.zip
 
  sudo mv terraform /usr/local/bin/.
} 

function setup_tf_libvirt() {
  cd
  mkdir kvm
  cd kvm
  terraform init
  cd .terraform.d
  mkdir plugins
  cd plugins
  wget https://github.com/dmacvicar/terraform-provider-libvirt/releases/download/v0.6.2/terraform-provider-libvirt-0.6.2+git.1585292411.8cbe9ad0.Ubuntu_18.04.amd64.tar.gz
  tar xvf terraform-provider-libvirt-0.6.2+git.1585292411.8cbe9ad0.Ubuntu_18.04.amd64.tar.gz
  rm terraform-provider-libvirt-0.6.2+git.1585292411.8cbe9ad0.Ubuntu_18.04.amd64.tar.gz
}

