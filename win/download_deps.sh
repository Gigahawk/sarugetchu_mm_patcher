#!/usr/bin/env bash

shopt -s extglob

mkdir -p md5
echo "Downloading md5 binary"
wget https://www.fourmilab.ch/md5/md5.tar.gz
tar -xvf md5.tar.gz -C md5
echo "Cleaning up"
rm md5.tar.gz
rm md5/!(md5.exe)

mkdir -p qemu
echo "Downloading portable qemu binaries"
wget https://github.com/dirkarnez/qemu-portable/releases/download/20240822/qemu-w64-portable-20240822.zip
unzip qemu-w64*.zip -d qemu
echo "Cleaning up"
rm qemu-w64*.zip
