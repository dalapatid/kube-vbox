# kolla based openstack in single centos7 VM in ubuntu host

# check if an apt package installed
function check_apt_pkgs() {
  pkgs=$@
  for pkg in $pkgs
  do
    dpkg-query -W $pkg
  done
}

KVM_PKGS="qemu-kvm libvirt-bin bridge-utils virt-manager"

check_apt_pkgs $KVM_PKGS

function install_pkgs() {
  pkgs=$@
  sudo apt-get install -y $pkgs
}

install_pkgs $KVM_PKGS

# A bridged adapter seems to be present already from virtualBox install
# likely need another one for KVM
 
# tools to create guests under KVM - virt-manager (GUI), virt-install (python script by RedHat), ubuntu-vm-builder (by cannonical)
# VMs kept by default in /var/lib/libvirt/images



