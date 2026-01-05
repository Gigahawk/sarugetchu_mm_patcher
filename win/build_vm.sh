#!/usr/bin/env bash

IMG_NAME=ssmm_build_vm.qcow2

echo "Cleaning old images"
rm -f "$IMG_NAME"

echo "Downloading alpine-make-vm-image"
wget https://raw.githubusercontent.com/alpinelinux/alpine-make-vm-image/v0.13.2/alpine-make-vm-image \
    && echo '2720b23e4c65aff41a3ab781a26467b66985c526  alpine-make-vm-image' | sha1sum -c \
    || exit 1
chmod +x alpine-make-vm-image

echo "Building VM"
sudo ./alpine-make-vm-image \
    --image-format qcow2 \
    --image-size 96G \
    --packages "$(cat vm_conf/packages)" \
    --fs-skel-dir vm_conf/rootfs \
    --fs-skel-chown root:root \
    --script-chroot \
    "$IMG_NAME" -- ./vm_conf/configure.sh $GIT_SHA

echo "Cleaning up"
rm alpine-make-vm-image