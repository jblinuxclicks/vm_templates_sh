#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

. /root/init/redhat/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ; 
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ; 
fi

dnf -y check-update ; dnf -y upgrade
dnf --setopt=install_weak_deps=False -y install @core dnf-plugins-core yum-utils sudo openssl

distro="$(rpm -qf --queryformat '%{NAME}' /etc/redhat-release | cut -f 1 -d '-')" 
if [ "$distro" != 'redhat' ] ; then
  dnf -y clean all ;
fi
if command -v zpool > /dev/null 2>&1 ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  fstrim -av ;
fi
sync
