#!/bin/sh
#
# Second part of the guestfish script, which migrates filesystem of an OpneVZ container into KVM virtual machine disk
#
# Description:
#
# This part alters the files of a newly created VM and adds parts of the configuration which were removed when used by OpenVZ

set -e

# alter this for another distro
distro=wheezy

VM=$1
SIZE=${2:-4G}
HV_VG=${3:-vg1}
# volume group of the virtual machine
VM_VG=vg${VM}01

maindisk=lv$VM
maindisk_path=/dev/$HV_VG/$maindisk

bootdisk=${maindisk}-boot
bootdisk_path=/dev/$HV_VG/$bootdisk

# root disk path as reference through the volume group inside of the
# VM
vm_root_disk_path=/dev/$VM_VG/lvroot
vm_swap_disk_path=/dev/$VM_VG/lvswap

# --- phase 2 ---
hv_fstab=$(dirname $0)/$VM-fstab
pkgs_list=pkgs2install.${distro}.txt
pkgs_src_file=$(dirname $0)/$pkgs_list
apt_sources=$(dirname $0)/apt-sources.${distro}.list

cat << EOF > $hv_fstab
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
$vm_root_disk_path    /        ext4    errors=remount-ro 0       1
LABEL=boot            /boot    ext4    defaults          0       2
$vm_swap_disk_path    none     swap    sw                0       0
EOF

case $distro in
  squeeze)
    backports_sources="deb http://ftp.de.debian.org/debian-backports/ squeeze-backports main contrib non-free"
    ;;
  wheezy)
    backports_sources="deb http://ftp.cz.debian.org/debian/ wheezy-backports main contrib non-free"
    ;;
esac

cat << EOF > $apt_sources
deb http://ftp.cz.debian.org/debian/ ${distro} main contrib non-free
deb-src http://ftp.cz.debian.org/debian/ ${distro} main contrib non-free

deb http://security.debian.org/ ${distro}/updates main contrib non-free
deb-src http://security.debian.org/ ${distro}/updates main contrib non-free

deb http://ftp.cz.debian.org/debian/ ${distro}-updates main contrib non-free
deb-src http://ftp.cz.debian.org/debian/ ${distro}-updates main contrib non-free

$backports_sources
EOF

guestfish --rw --network --add $bootdisk_path --add $maindisk_path <<EOF
launch
vg-activate-all true 
mount $vm_root_disk_path /
rm-f /etc/rc6.d/K00vzreboot
cp /usr/share/sysvinit/inittab /etc/inittab
sh '/sbin/e2label /dev/sda1 boot'
mount /dev/sda1 /boot/
write /etc/apt/apt.conf.d/02cache 'APT::Cache-Limit "164165824";'
upload $apt_sources /etc/apt/sources.list
upload $pkgs_src_file /$pkgs_list
upload $hv_fstab /etc/fstab
sh 'apt-get update'
sh "DEBIAN_FRONTEND=noninteractive apt-get install -y \`cat /$pkgs_list\`"
sh 'grub-install /dev/sda'
sh 'update-grub'
rm-f /etc/udev/rules.d/70-persistent-net.rules
shutdown
EOF
# --- END - phase 2 ---

