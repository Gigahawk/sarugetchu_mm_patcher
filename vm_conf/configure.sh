#!/bin/sh

# Nix installer depends on this for some reason
echo "Mounting pseudoterminal device"
mount -t devpts devpts /dev/pts

# Workaround for error: the group 'nixbld' specified in 'build-users-group' does not exist
echo "Unsetting build-users-group"
mkdir -p /etc/nix
echo "build-users-group =" > /etc/nix/nix.conf

# Workaround for error: cannot perform a sandboxed build because user namespaces are not enabled
echo "Disabling sandboxed builds"
echo "sandbox = false" >> /etc/nix/nix.conf

echo "Enabling flakes"
echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

echo "Setting download buffer size to 1G"
echo "download-buffer-size = 1073741824" >> /etc/nix/nix.conf

echo "Installing nix"
# Can't use determinate installer inside chroot unfortunately
#curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
# sh -s -- install linux --determinate --no-confirm --init none --option sandbox false
sh <(curl -L https://nixos.org/nix/install) --no-daemon
echo $?

echo "Adding nix commands to profile"
echo ". /root/.nix-profile/etc/profile.d/nix.sh" > /root/.profile

echo "Activating nix"
. /root/.nix-profile/etc/profile.d/nix.sh

echo "Downloading ssmm-patcher"
curl -L -o /root/master.zip https://github.com/Gigahawk/sarugetchu_mm_patcher/archive/refs/heads/master.zip
cd /root
unzip master.zip
cd sarugetchu_mm_patcher-master

# We use archive.org to download a leaked PS2 SDK, probably best that I
# don't redistribute this so blocking it for now
echo "Blocking archive.org downloads"
sudo iptables -A OUTPUT -d archive.org -j REJECT

# HACK: build from scratch fails due to homeless shelter, just
# run the build in a loop while clearing it all the time
# https://github.com/NixOS/nix/issues/8313
i=1
while [ "$i" -le 100 ]
do
    echo "Clearing homeless shelter"
    rm -rf /homeless-shelter

    echo "Clearing log"
    rm -rf output.log

    echo "Prefetching nix bins $i"
    nix build .#iso-patched --keep-going 2>&1 | tee output.log

    echo "Checking output log"
    if grep -q "please remove it to assure purity of builds without sandboxing" output.log; then
        echo "Build failed due to homeless shelter, retrying build"
    else
        echo "Build completed"
        break
    fi
    i=$((i + 1))

done

echo "Clearing homeless shelter"
rm -rf /homeless-shelter
