#!/bin/sh -x

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'
# perl -e 'print crypt("password", "\$6\$16CHARACTERSSALT") . "\n"'

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

## WITHOUT availability of netcat or ssh/scp on system:
##  (host) simple http server for files: python -m http.server {port}
##  (client) tools:
##    [curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file

# example usage ([defaults]):
#   [VOL_MGR=zfs] sh vminstall_auto.sh [freebsd [freebsd-Release-${VOL_MGR}]]

STORAGE_DIR=${STORAGE_DIR:-$(dirname $0)}
ISOS_PARDIR=${ISOS_PARDIR:-/mnt/Data0/distros}

cp -R $HOME/.ssh/publish_krls init/common/skel/_ssh/

freebsd() {
  VOL_MGR=${VOL_MGR:-zfs} ; GUEST=${1:-freebsd-Release-${VOL_MGR}}
  variant=freebsd
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/freebsd -name 'FreeBSD-*-amd64-disc1.iso' | tail -n1)}
  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  (cd ${ISOS_PARDIR}/freebsd ; sha256sum --ignore-missing -c CHECKSUM.SHA256-FreeBSD-*-RELEASE-amd64) ; sleep 5
  tar -cf /tmp/init.tar init/common init/freebsd
  
  echo "### Once network connected, transfer needed file(s) ###" ; sleep 5
  
  ## NOTE, saved auto install config: /root/installscript
  
  ##!! (bsdinstall) navigate to single user: 2
  ##!! if late, Live CD -> root/-
  
  #mdmfs -s 100m md1 /tmp ; cd /tmp ; ifconfig
  #dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.{ifdev} {ifdev}
  
  ## (FreeBSD) install with bsdinstall script
  ## NOTE, transfer [dir(s) | file(s)]: init/common, init/freebsd
  
  #geom -t
  #[CRYPTED_PASSWD=$CRYPTED_PASSWD] [INIT_HOSTNAME=freebsd-boxv0000] [DEVX=[da0|vtbd0]] bsdinstall script init/freebsd/zfs-installerconfig
}

devuan() {
  VOL_MGR=${VOL_MGR:-lvm} ; GUEST=${1:-devuan-Stable-${VOL_MGR}}
  variant=debian
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/devuan -name 'devuan_*_amd64*desktop.iso' | tail -n1)}
  #INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---location="http://deb.devuan.org/devuan/dists/stable/main/installer-amd64"}
  INITRD_INJECT_OPTS=${INITRD_INJECT_OPTS:---initrd-inject="/tmp/preseed.cfg" --initrd-inject="/tmp/init.tar"}
  EXTRA_ARGS_OPTS=${EXTRA_ARGS_OPTS:---extra-args="auto=true preseed/url=file:///preseed.cfg locale=en_US keymap=us console-setup/ask_detect=false domain= hostname=devuan-boxv0000 mirror/http/hostname=deb.devuan.org mirror/http/directory=/merged"}
  if [ ! "" = "$ISO_PATH" ] ; then
    (cd ${ISOS_PARDIR}/devuan ; sha256sum --ignore-missing -c SHA256SUMS) ;
    sleep 5 ;
  fi
  cp init/debian/${VOL_MGR}-preseed.cfg /tmp/preseed.cfg
  tar -cf /tmp/init.tar init/common init/debian
  
  ## NOTE, debconf-get-selections [--installer] -> auto install cfg
}

debian() {
  VOL_MGR=${VOL_MGR:-lvm} ; GUEST=${1:-debian-Stable-${VOL_MGR}}
  variant=debian
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/debian -name 'debian-*-amd64-*-CD-1.iso' | tail -n1)}
  #INST_SRC_OPTS=${INST_SRC_OPTS:---location="${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---location="http://deb.debian.org/debian/dists/stable/main/installer-amd64"}
  INITRD_INJECT_OPTS=${INITRD_INJECT_OPTS:---initrd-inject="/tmp/preseed.cfg" --initrd-inject="/tmp/init.tar"}
  EXTRA_ARGS_OPTS=${EXTRA_ARGS_OPTS:---extra-args="auto=true preseed/url=file:///preseed.cfg locale=en_US keymap=us console-setup/ask_detect=false domain= hostname=debian-boxv0000 mirror/http/hostname=ftp.us.debian.org mirror/http/directory=/debian"}
  if [ ! "" = "$ISO_PATH" ] ; then
    (cd ${ISOS_PARDIR}/debian ; sha256sum --ignore-missing -c SHA256SUMS) ;
    sleep 5 ;
  fi
  cp init/debian/${VOL_MGR}-preseed.cfg /tmp/preseed.cfg
  tar -cf /tmp/init.tar init/common init/debian
  
  ## NOTE, debconf-get-selections [--installer] -> auto install cfg
}

#----------------------------------------
${@:-freebsd}
  
OUT_DIR=${OUT_DIR:-build/${GUEST}}
mkdir -p ${OUT_DIR}
qemu-img create -f qcow2 ${OUT_DIR}/${GUEST}.qcow2 30720M

#------------ using qemu-system-* ---------------
#QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${STORAGE_DIR}/OVMF/OVMF_CODE.fd"}
#echo "Verify bridge device allowed in /etc/qemu/bridge.conf" ; sleep 3
#cat /etc/qemu/bridge.conf ; sleep 5
#echo "(if needed) Quickly catch boot menu to add kernel boot parameters"
#sleep 5
#
#qemu-system-x86_64 -machine accel=kvm:hvf:tcg -smp cpus=2 -m size=2048 \
#  -boot order=cdn,menu=on -usb -device usb-tablet \
#  -net nic,model=virtio-net-pci,macaddr=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
#  ${NET_OPTS:--net bridge,br=virbr0} \
#  -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
#  -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
#  -cdrom ${ISO_PATH} ${QUEFI_OPTS} -name ${GUEST} &
#
#echo "### Once network connected, transfer needed file(s) ###"
#------------------------------------------------

#-------------- using virtinst ------------------
CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
VUEFI_OPTS=${VUEFI_OPTS:---boot uefi}

## NOTE, to convert qemu-system args to libvirt domain XML:
#  eval "echo \"$(< vminstall_qemu.args)\"" > /tmp/install_qemu.args
#  virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/install_qemu.args

if [ "" = "${EXTRA_ARGS_OPTS}" ] ; then
virt-install ${CONNECT_OPT} --memory 2048 --vcpus 2 \
  --controller usb,model=ehci --controller virtio-serial \
  --console pty,target_type=virtio --graphics vnc,port=-1 \
  --network network=default,model=virtio-net,mac=RANDOM \
  --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
  --disk path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi,format=qcow2 \
  ${INST_SRC_OPTS} ${VUEFI_OPTS} -n ${GUEST} ${INITRD_INJECT_OPTS} &
else
virt-install ${CONNECT_OPT} --memory 2048 --vcpus 2 \
  --controller usb,model=ehci --controller virtio-serial \
  --console pty,target_type=virtio --graphics vnc,port=-1 \
  --network network=default,model=virtio-net,mac=RANDOM \
  --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
  --disk path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi,format=qcow2 \
  ${INST_SRC_OPTS} ${VUEFI_OPTS} -n ${GUEST} ${INITRD_INJECT_OPTS} \
  "${EXTRA_ARGS_OPTS}" &
fi

sleep 30 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST}
#sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > ${OUT_DIR}/${GUEST}.xml
#------------------------------------------------

cp init/${variant}/Vagrantfile init/common/qemu_lxc/vmrun* ${OUT_DIR}/
sleep 30
