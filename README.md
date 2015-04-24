# chroot2kvm
A set of scripts that allow converting a chroot environment to a working KVM machine.

The implementation uses libguestfs and associated tools.

# Limitations

The scripts are relatively simple to modify. Currently, they support converting Debian Squeeze and Debian Wheezy.
However, it is very simple provide custom sources lists or use them for other Linux distributions.

# Components

## vz2kvm-clone.sh

Migrates filesystem of a chroot environment into a KVM virtual machine disk
Creates LVM logical volumes for the new VM, formats them and copies the contents of the original filesystem into newly created LV.
The VM itself (.xml configuration for libvirt) is not created by this scrip.

## vz2kvm-setup.sh

Alters the files of the newly created VM disk and adds parts of the configuration which were not present on the original environment.
The list of the missing packages is provided in this project.
One needs to specify the distribution name of the migrated system in the beginning of this script. Default is Wheezy.


# Implementation notes

## Rsync-in variant

This cannot be used for host copying since the rsync client
implemented in guestfish does not support all rsync options
(only archive and deletedest

    $ rsync --daemon --address=localhost --port=2999


Guest fish has to be launched with --network:

    $ guestfish --network --add /dev/some-device
  

    <fs> rsync-in rsync://192.168.122.1:2999/test/ / archive:true


## Guestfish - example to create a new machine

The machine has:

  - `/boot` in separate partition
  


Example guestfish session:

    launch  
    vgcreate vg01 /dev/sdb
    vg-activate true vg01
    lvcreate lvswap  vg01 512
    lvcreate-free lvroot vg01 100
    mkfs ext4 /dev/vg01/lvroot
    mkswap /dev/vg01/lvswap
    mount /dev/vg01/lvroot /


Mount machine filesystem:

    guestmount --trace --add /dev/vg1/lvmachine --mount /dev/vgmachine01/lvroot /mnt/vz

Rsync and unmount of the filesystem:

    rsync -aAHXvz --numeric-ids ./ /mnt/vz/
    fusermount -u /mnt/vz

