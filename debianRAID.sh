#!/bin/bash

#Based on:
#http://www.fabbnet.net/Live_Persistent.htm
#https://willhaley.com/blog/custom-debian-live-environment/

apt-get install \
   debootstrap \
   squashfs-tools \
   xorriso \
   grub-pc-bin \
   grub-efi-amd64-bin \
   mtools -y
rm -rf $HOME/LIVE_BOOT
mkdir $HOME/LIVE_BOOT && \
debootstrap \
   --arch=amd64 \
   --variant=minbase \
   stretch \
   $HOME/LIVE_BOOT/chroot \
   http://ftp.debian.org/debian/

#Instalando snapraid
apt-get install gcc git make wget -y && \
wget https://github.com/amadvance/snapraid/releases/download/v11.2/snapraid-11.2.tar.gz -O snapraid.tar.gz && \
tar -xzvf ./snapraid.tar.gz && \
cd snapraid-11.2 && \
./configure && \
make
cd .. && \
cp snapraid-11.2/snapraid $HOME/LIVE_BOOT/chroot/usr/local/bin/snapraid && \
cp snapraid-11.2/snapraid.conf.example $HOME/LIVE_BOOT/chroot/etc/snapraid.conf && \
rm -rf ./snapraid.tar.gz snapraid-11.2

mkdir -p $HOME/LIVE_BOOT/chroot/share \
    $HOME/LIVE_BOOT/chroot/share/Download \
    $HOME/LIVE_BOOT/chroot/share/Files \
    $HOME/LIVE_BOOT/chroot/share/Media \
    $HOME/LIVE_BOOT/chroot/share/ISO \
    $HOME/LIVE_BOOT/chroot/share/timemachine

#apt-get install \
#    linux-image-amd64 \
#    live-boot \
#    locales \
#    systemd-sysv \
#    curl openssh-client \
#    xfsprogs \
#    ssh \
#    smbclient tmux gdisk \
#    fuse mergerfs tmux atop \
#    bcache-tools \
#    vim whiptail \
#    qemu-kvm ovmf uml-utilities libvirt-daemon \
#    bridge-utils network-manager iputils-ping \
#    apt-transport-https \
#    ca-certificates curl \
#    gnupg2 software-properties-common \
#    blackbox xterm xserver-xorg-core \
#    lightdm \
#    xserver-xorg xinit virt-manager -y

mount -t proc proc $HOME/LIVE_BOOT/chroot/proc && \
mount -t devpts devpts $HOME/LIVE_BOOT/chroot/dev/pts

chroot $HOME/LIVE_BOOT/chroot <<EOF
  curl -sL "https://raw.githubusercontent.com/cjuniorfox/debianraid/master/debianraid_chroot.sh" | bash -
EOF

umount $HOME/LIVE_BOOT/chroot/proc && \
umount $HOME/LIVE_BOOT/chroot/dev/pts

