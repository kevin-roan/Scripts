#!/usr/bin/env bash
 
# ludan-install.sh - Simple Arch Linux Installation Script
# mbr (non uefi installation)
#didn't added extra packages, such as 
sub-firmware, add it to specific lines if you want. 
#didn't added chaotic aur repo. Install it after installation loml

# default settings (you can override these using option arguments)
hostname="ludan"
#keymap def is us btw.
keymap="us"
timezone="Asia/Kolkata"
disk=""
wipedisk=0
reboot=0
rootpass="root"
packages=""
mkfsoptions=""

#from salik

usage () {
  echo "USAGE: ${0##*/} [OPTIONS]"
  echo ""
  echo "OPTIONS:"
  echo "-d|--disk <disk>          Disk to install to (MANDATORY)"
  echo "-h|--help                 Show usage help (you're just reading it)"
  echo "-H|--hostname <hostname>  Set hostname"
  echo "-k|--keymap <keymap>      Set keymap"
  echo "-n|--nodiscard <1|0>      Set to 1 to use \"-E nodiscard\" with mkfs"
  echo "-p|--packages <packages>  List of additional packages to install"
  echo "-r|--reboot <1|0>         Set to 1 to reboot after successful installation"
  echo "-t|--timezone <timezone>  Set timezone"
  echo "-w|--wipedisk <1|0>       Set to 1 to wipe disk before installation"
  echo ""
  echo "EXAMPLES:"
  echo "${0##*/} -d /dev/sda"
  echo "${0##*/} -H myhostname -k de -t Europe/Berlin -d /dev/sda -w 1 -r 1"
  echo "${0##*/} -w 1 -r 1 -p \"wpa_supplicant dhcpcd vim\" -H foo -d /dev/sda"
  echo ""
}

# use $ROOTPASS environment variable (if set)
if  "$ROOTPASS" != "" ; then
  rootpass="$ROOTPASS"
fi

# show usage help when we got no arguments
if  "$#" -eq 0 ; then
  usage
  exit 255
fi

# argument parsing
while  "$#" -gt 0 ; do
  case "$1" in
    -p|--packages)
      shift
      packages="$1"
      shift
      ;;
    -h|--help)
      shift
      usage
    ;;
    -H|--hostname)
      shift
      hostname="$1"
      shift
    ;;
    -n|--nodiscard)
      shift
      if  "$1" -gt 0 ; then
        mkfsoptions="${mkfsoptions} -E nodiscard"
        shift
      fi
    ;;
    -k|--keymap)
      shift
      keymap="$1"
      shift
    ;;
    -t|--timezone)
      shift
      timezone="$1"
      shift
    ;;
    -d|--disk)
      shift
      disk="$1"
      shift
    ;;
    -w|--wipedisk)
      shift
      wipedisk="$1"
      shift
    ;;
    -D|--desktop)
      shift
      desktop="$1"
      shift
    ;;
    -r|--reboot)
      shift
      reboot="$1"
      shift
    ;;
    -R|--rootpass)
      shift
      rootpass="$1"
      shift
    ;;
    *)
      echo "USAGE ERROR."
      usage
      exit 255
    ;;
  esac
done

set -ex

# check if disk specified
if  "$disk" == "" ; then
  echo "ERROR: no disk specified"
  exit 255
fi

# check mounts
if  "$(cut -f 1 -d " " /proc/mounts | grep "$disk" | wc -l)" -gt 0 ; then
  echo "ERROR: ACTIVE PARTITIONS FOUND. Un-mount them and try again. Exiting."
  exit 255
fi

# wipe full hard disk
if  "$wipedisk" -gt 0 ; then
  dd if=/dev/zero of="$disk" bs=1M
fi

# partitioning
parted -s "${disk}" mktable msdos
parted -s "${disk}" mkpart primary 0% 1200m
parted -s "${disk}" mkpart primary 1200m 100%
parted -s "${disk}" set 1 boot on

# make filesystems
if  "${mkfsoptions}" == "" ; then
  mkfs.ext4 -F "${disk}"1
  mkfs.ext4 -F "${disk}"2
else
  mkfs.ext4 -F ${mkfsoptions} "${disk}"1
  mkfs.ext4 -F ${mkfsoptions} "${disk}"2
fi

# mounts
mount "${disk}"2 /mnt
mkdir /mnt/boot
mount "${disk}"1 /mnt/boot

#Add/Remove packages from here
# pacstrap system
pacstrap /mnt base base-devel vim htop tmux openssh kitty firefox emacs telegram-desktop min bat 

# generate fstab
genfstab -U -p /mnt >> /mnt/etc/fstab

#fstab results
cat /mnt/etc/fstab

# chroot
arch-chroot /mnt /bin/bash <<EOF
set -ex
pacman --noconfirm -Syy
pacman --noconfirm -S reflector
#Mirror (From tiwari)

sudo reflector --latest 100 --age 6 --fastest 20 --threads 20 --save /etc/pacman.d/mirrorlist --verbose --sort rate

#end of mirror 

echo KEYMAP="$keymap" > /etc/vconsole.conf
echo "$hostname" >/etc/hostname
ln -s /usr/share/zoneinfo/"$timezone" /etc/localtime
hwclock --systohc
locale >/etc/locale.conf
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
locale-gen

if  "$packages" == "" ; then
  pacman --noconfirm -S linux-firmware linux grub mkinitcpio
else
  pacman --noconfirm -S linux-firmware linux grub mkinitcpio $packages
fi

mkinitcpio -p linux
grub-install --target=i386-pc --recheck "${disk}"
# set grub output to plain text
sed -iE 's|^#GRUB_TERMINAL_OUTPUT=console|GRUB_TERMINAL_OUTPUT=console|' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
echo root:"$rootpass" | chpasswd
EOF

# chroot ended, time to unmount
#umount /mnt 
#umount /mnt/hdd/

# unmount /mnt and /mnt/boot
umount /mnt/{boot,}

# reboot system
tput setaf 2
if  "$reboot" -gt 0 ; then
  echo "Rembooting system..."
  sleep 3
  tput sgr0
  reboot
else
  echo "Instamllation complemte. Remove usb then reboomt"
  tput sgr0
fi

