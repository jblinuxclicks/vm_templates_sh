#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

. /root/init/archlinux/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ; 
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ; 
fi

if command -v systemctl > /dev/null 2>&1 ; then
  systemctl stop pamac ;
elif command -v rc-update > /dev/null 2>&1 ; then
  rc-service pamac stop ;
fi
rm /var/lib/pacman/db.lck
set -e
pacman --noconfirm -Syy ; pacman --noconfirm -Syu
pacman --noconfirm --needed -S base which sudo

pacman --noconfirm -Sc
if command -v zpool > /dev/null 2>&1 ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  fstrim -av ;
fi
sync
