#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

. /root/init/openbsd/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/ksh.kshrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/ksh.kshrc ; 
fi
if [ -z "$(grep '^fdesc' /etc/fstab)" ] ; then
  echo 'fdesc  /dev/fd  fdescfs  rw  0  0' >> /etc/fstab ; 
fi

pkg_add -u
pkg_add sudo--

# #?? clean
DEVX=${DEVX:-sd0}
#fsck_ffs /dev/${DEVX}a
#fsck_ffs /dev/${DEVX}d
sync
