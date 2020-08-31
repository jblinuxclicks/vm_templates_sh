#!/bin/sh -eux

## scripts/upgradepkgs.sh
MIRROR=${MIRROR:-spout.ussg.indiana.edu}

os_version=$(grep VERSION= /etc/os-release | cut -f2 -d\" | cut -f1 -d\ )

set +e

. /root/init/pclinuxos/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ; 
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ; 
fi

grep -e '^rpm.*' /etc/apt/sources.list ; sleep 5
apt-get -y update
apt-get -y --fix-broken install
apt-get -y upgrade ; apt-get -y dist-upgrade
apt-get -y --option Retries=3 install sudo

apt-get -y clean
if command -v zpool > /dev/null 2>&1 ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  fstrim -av ;
fi
sync
