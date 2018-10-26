#!/bin/bash
set -e # stop script on error
CONFIG_DIRECTORY=/mnt/etc/nixos
GITHUB_REPO=platyplus/remote-host
[ -z "$API_ENDPOINT" ] && API_ENDPOINT=https://graphql.platyplus.io

# Set the hard drive
DEFAULTTGTDEV="/dev/sda"
read -p "Destination hard drive (default: $DEFAULTTGTDEV): " TGTDEV
[ "$TGTDEV" == '' ] && TGTDEV=$DEFAULTTGTDEV

# TODO: mute fdisk
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${TGTDEV}
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
   # default - start at beginning of disk 
  +1G # 1 GB boot parttion
  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  t # change type of partition
  2 # select partition number 2
  8e # select LVM type
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

# Create the LVM volumes
pvcreate ${TGTDEV}2
vgcreate LVMVolGroup ${TGTDEV}2
lvcreate -l 100%FREE -n nixos_root LVMVolGroup

# Format the partitions
mkfs.ext4 -L nixos_boot ${TGTDEV}1
mkfs.ext4 -L nixos_root /dev/LVMVolGroup/nixos_root

mount /dev/disk/by-label/nixos_root /mnt
mkdir /mnt/boot
mount /dev/disk/by-label/nixos_boot /mnt/boot
nixos-generate-config --root /mnt
curl -L "https://github.com/$GITHUB_REPO/archive/master.zip" --output /tmp/config.zip
cd /tmp
unzip config.zip
mv NixOS-master/* "$CONFIG_DIRECTORY"
mv NixOS-master/.gitignore "$CONFIG_DIRECTORY"

# Local settings: settings that are dependent to the hardware and therefore that
# are not required to store on the cloud server if we need to reinstall on new hardware
cp "$CONFIG_DIRECTORY/settings.nix.template" "$CONFIG_DIRECTORY/settings.nix"

# Find a stable device name for grub and set it in the configuration
DEVICEID=`ls -l /dev/disk/by-id/ | grep "${TGTDEV##*/}$" | awk '{print $9}'`
sed -i -e 's/{{device}}/'"${DEVICEID//\//\\/}"'/g' "$CONFIG_DIRECTORY/settings.nix"

# Install the programms required to run the script
nix-env -iA nixos.jq

# Set the host name
DEFAULTHOSTNAME="hostname"
read -p "Host name (default: $DEFAULTHOSTNAME): " NEWHOSTNAME
[ "$NEWHOSTNAME" == '' ] && NEWHOSTNAME=$DEFAULTHOSTNAME
sed -i -e 's/{{hostname}}/'"$NEWHOSTNAME"'/g' "$CONFIG_DIRECTORY/settings.nix"

# Set the time zone
DEFAULTTIMEZONE="Europe/Brussels"
read -p "Host name (default: $DEFAULTTIMEZONE): " TIMEZONE
[ "$TIMEZONE" == '' ] && TIMEZONE=$DEFAULTTIMEZONE
sed -i -e 's/{{timezone}}/'"$TIMEZONE"'/g' "$CONFIG_DIRECTORY/settings.nix"

# Set the tunnel port
DEFAULTTUNNELPORT=6000
read -p "Host name (default: $DEFAULTTUNNELPORT): " TUNNELPORT
[ "$TUNNELPORT" == '' ] && TUNNELPORT=$DEFAULTTUNNELPORT
sed -i -e 's/{{tunnelport}}/'"$TUNNELPORT"'/g' "$CONFIG_DIRECTORY/settings.nix"

cp "$CONFIG_DIRECTORY/static-network.nix.template" "$CONFIG_DIRECTORY/static-network.nix"

# Set the interface
DEFAULTINTERFACE=`ip route | grep default | awk '{print $5}'`
read -p "Network interface (default: $DEFAULTINTERFACE): " INTERFACE
[ "$INTERFACE" == '' ] && INTERFACE=$DEFAULTINTERFACE
sed -i -e 's/{{interface}}/'"$INTERFACE"'/g' "$CONFIG_DIRECTORY/static-network.nix"

# Set the ip address
DEFAULTADDRESS=`ip route | grep default | awk '{print $7}'`
read -p "IP Address (default: $DEFAULTADDRESS): " ADDRESS
[ "$ADDRESS" == '' ]] && ADDRESS=$DEFAULTADDRESS
sed -i -e 's/{{address}}/'"$ADDRESS"'/g' "$CONFIG_DIRECTORY/static-network.nix"

# Set the gateway
DEFAULTGATEWAY=`ip route | grep default | awk '{print $3}'`
read -p "Gateway (default: $DEFAULTGATEWAY): " GATEWAY
[ "$GATEWAY" == '' ] && GATEWAY=$DEFAULTGATEWAY
sed -i -e 's/{{gateway}}/'"$GATEWAY"'/g' "$CONFIG_DIRECTORY/static-network.nix"

echo "IP address: $ADDRESS"
[ -f "$CONFIG_DIRECTORY/../issue" ] && echo "IP address: $ADDRESS (remove this line from /etc/issue)" >> "$CONFIG_DIRECTORY/../issue"

# Installi NixOS
nixos-install --no-root-passwd --max-jobs 4

echo "Please remove the installation disk and reboot the machine"