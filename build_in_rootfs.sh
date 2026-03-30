#!/bin/bash

USERNAME="root"
PASSWORD="root"

mount -t proc /proc /proc
mount -t sysfs /sys /sys
mount -t devtmpfs /dev /dev

echo "Ubuntu" > /etc/hostname
echo "${USERNAME}:${PASSWORD}" | chpasswd
#apt -y update && apt -y upgrade
#apt install -y vim build-essential

umount /proc
umount /sys
umount /dev

