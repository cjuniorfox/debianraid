#!/bin/bash
echo "$1";
export disk=/dev/$1 #sdz = thumbdrive

#Cria imagem
mkdir -p $HOME/LIVE_BOOT/{scratch,image/live} && \
mksquashfs \
    $HOME/LIVE_BOOT/chroot \
    $HOME/LIVE_BOOT/image/live/filesystem.squashfs \
    -e boot && \
cp $HOME/LIVE_BOOT/chroot/boot/vmlinuz-* \
    $HOME/LIVE_BOOT/image/vmlinuz && \
cp $HOME/LIVE_BOOT/chroot/boot/initrd.img-* \
    $HOME/LIVE_BOOT/image/initrd && \
cat <<'EOF' >$HOME/LIVE_BOOT/scratch/grub.cfg
search --set=root --file /DEBIAN_CUSTOM
insmod all_video
set default="0"
set timeout=5
menuentry "DebianRAID" {
    linux /vmlinuz boot=live persistence intel_iommu=on
    initrd /initrd
}
menuentry "DebianRAID RAM" {
    linux /vmlinuz boot=live persistence toram intel_iommu=on
    initrd /initrd
}
menuentry "DebianRAID (VGA)" {
    linux /vmlinuz boot=live quiet nomodeset persistence toram intel_iommu=on
    initrd /initrd
}
EOF

touch $HOME/LIVE_BOOT/image/DEBIAN_CUSTOM

mkdir -p /mnt/{usb,efi,persistence}
parted --script $disk \
    mklabel gpt \
    mkpart primary fat32 2048s 4095s \
        name 1 BIOS \
        set 1 bios_grub on \
    mkpart ESP fat32 4096s 413695s \
        name 2 EFI \
        set 2 esp on \
    mkpart primary fat32 413696s 8226562s \
        name 3 LINUX \
        set 3 msftdata on \
    mkpart primary ext4 8226563s 100% \
        name 4 persistence

gdisk $disk << EOF
r     # recovery and transformation options
h     # make hybrid MBR
1 2 3 # partition numbers for hybrid MBR
N     # do not place EFI GPT (0xEE) partition first in MBR
EF    # MBR hex code
N     # do not set bootable flag
EF    # MBR hex code
N     # do not set bootable flag
83    # MBR hex code
Y     # set the bootable flag
x     # extra functionality menu
h     # recompute CHS values in protective/hybrid MBR
w     # write table to disk and exit
Y     # confirm changes
EOF
 mkfs.vfat -F32 ${disk}2 && \
 mkfs.vfat -F32 ${disk}3 && \
 mkfs.ext4 ${disk}4 -L persistence

 mount ${disk}2 /mnt/efi && \
 mount ${disk}3 /mnt/usb
 mount ${disk}4 /mnt/persistence

 grub-install \
    --target=x86_64-efi \
    --efi-directory=/mnt/efi \
    --boot-directory=/mnt/usb/boot \
    --removable \
    --recheck

 grub-install \
    --target=i386-pc \
    --boot-directory=/mnt/usb/boot \
    --recheck \
    $disk

mkdir -p /mnt/usb/{boot/grub,live}

cp -r $HOME/LIVE_BOOT/image/* /mnt/usb/
 
cp \
    $HOME/LIVE_BOOT/scratch/grub.cfg \
    /mnt/usb/boot/grub/grub.cfg


echo '/ union' | tee --append /mnt/persistence/persistence.conf

umount /mnt/{usb,efi,persistence}