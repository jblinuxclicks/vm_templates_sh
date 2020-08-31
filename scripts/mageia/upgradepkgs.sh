#!/bin/sh -eux

## scripts/upgradepkgs.sh
MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/mageia}

set +e

. /root/init/mageia/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ; 
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ; 
fi

#urpmq --list-url ; sleep 5
#urpmi.update -a ; urpmi --auto-update
dnf repolist enabled ; sleep 5
dnf -y check-update ; dnf -y upgrade
#urpmi --no-recommends sudo
dnf -y --setopt=install_weak_deps=False install sudo

dnf -y clean all
if command -v zpool > /dev/null 2>&1 ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  fstrim -av ;
fi
sync
