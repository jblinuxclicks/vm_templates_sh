#!/bin/sh -eux

## netbsd/vagrantuser.sh
#mkdir -p /home/vagrant
#DIR_MODE=0750 
useradd -m -G wheel,operator -s /bin/ksh -c 'Vagrant User' vagrant
usermod -p $(pwhash vagrant) vagrant
#echo 'set prompt = "%N@%m:%~ %# "' >> /home/vagrant/.cshrc
chown -R vagrant:$(id -gn vagrant) /home/vagrant

#sh -c 'cat >> /usr/pkg/etc/sudoers.d/99_vagrant' << EOF
#Defaults:vagrant !requiretty
#$(id -un vagrant) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /usr/pkg/etc/sudoers.d/99_vagrant

pubkey_url="https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub"
mkdir -p /home/vagrant/.ssh
if command -v wget > /dev/null 2>&1 ; then
    wget --no-check-certificate -O /home/vagrant/.ssh/authorized_keys "$pubkey_url" ;
elif command -v curl > /dev/null 2>&1 ; then
    curl --insecure --location -o /home/vagrant/.ssh/authorized_keys "$pubkey_url" ;
elif command -v aria2c > /dev/null 2>&1 ; then
    aria2c --check-certificate=false -d / -o /home/vagrant/.ssh/authorized_keys "$pubkey_url" ;
elif command -v fetch > /dev/null 2>&1 ; then
    fetch --retry --mirror --no-verify-peer -o /home/vagrant/.ssh/authorized_keys "$pubkey_url" ;
elif command -v ftp > /dev/null 2>&1 ; then
    ftp -S dont -o /home/vagrant/.ssh/authorized_keys "$pubkey_url" ;
else
    echo "Cannot download vagrant public key" ;
    exit 1 ;
fi
chown -R vagrant:$(id -gn vagrant) /home/vagrant
chown -R vagrant:$(id -gn vagrant) /home/vagrant/.ssh
chmod -R go-rwsx /home/vagrant/.ssh
