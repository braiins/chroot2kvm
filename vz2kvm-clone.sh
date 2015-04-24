#!/bin/sh
#
# First part of the guestfish script, which migrates filesystem of an OpneVZ container into KVM virtual machine disk
#
# Description:
#
# This part creates LVM's logical volumes for the new VM, formats them and copies the contents of the original chroot filesystem used by OpenVZ as a VM container
# The VM itself (.xml configuration for libvirt) is not created by this script


set -e

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

# --- phase 1 ---
lvcreate -L 512M $HV_VG -n $bootdisk
lvcreate -L $SIZE $HV_VG -n $maindisk

echo -n "Preparing VM logical volumes - $bootdisk_path, $maindisk_path.."
guestfish --rw --add $bootdisk_path --add $maindisk_path <<EOF
launch
part-init /dev/sda msdos
part-add /dev/sda p 2048 -1
pvcreate /dev/sdb
vgcreate $VM_VG /dev/sdb
vg-activate-all true 
lvcreate lvswap $VM_VG 512
lvcreate-free `basename $vm_root_disk_path` $VM_VG 100
mkfs ext4 /dev/sda1
mkfs ext4 $vm_root_disk_path
mkswap $vm_swap_disk_path
shutdown
EOF
VM_ROOT_MNT_POINT=/tmp/$VM
mkdir -p $VM_ROOT_MNT_POINT
# Basic image installed, let's rsync the filesystem
guestmount --add $maindisk_path --mount $vm_root_disk_path $VM_ROOT_MNT_POINT
echo done

rsync -aAHXv --numeric-ids ./ $VM_ROOT_MNT_POINT

echo -n "Waiting for guestmount to terminated.."
sleep 5
fusermount -u $VM_ROOT_MNT_POINT
echo "done, unmounted"
# --- END - phase 1 ---

