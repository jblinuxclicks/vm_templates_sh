#!/bin/sh -x

# usage:
#   sh vmrun.sh import_[qemu | lxc] [GUEST]
#   sh vmrun.sh run_virsh [GUEST]
#   or
#   sh vmrun.sh run_qemu [GUEST]
#
# example ([defaults]):
#   sh vmrun.sh run_qemu [freebsd-Release-zfs]

STORAGE_DIR=${STORAGE_DIR:-$(dirname $0)} ; IMGEXT=${IMGEXT:-.qcow2}

#-------------- create Vagrant ------------------
box_vagrant() {
  GUEST=${1:-freebsd-Release-zfs}
  author=${author:-thebridge0491} ; datestamp=$(date +"%Y.%m.%d")
  if [ ! -e ${STORAGE_DIR}/metadata.json ] ; then
    echo '{"provider":"libvirt","virtual_size":30,"format":"qcow2"}' > \
      ${STORAGE_DIR}/metadata.json ;
  fi
  if [ ! -e ${STORAGE_DIR}/info.json ] ; then
    cat << EOF > ${STORAGE_DIR}/info.json ;
{
 "Author": "${author} <${author}-codelab@yahoo.com>",
 "Repository": "https://bitbucket.org/${author}/vm_templates_sh.git",
 "Description": "Virtual machine templates (KVM/QEMU hybrid boot: BIOS+UEFI) using auto install methods and/or chroot install scripts."
}
EOF
  fi
  if [ ! -e ${STORAGE_DIR}/Vagrantfile ] ; then
    cat << EOF > ${STORAGE_DIR}/Vagrantfile ;

# minimal contents
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = 'kvm'
  end
end


# custom contents
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.ssh.shell = 'sh'
  config.vm.boot_timeout = 1800
  config.vm.synced_folder '.', '/vagrant', disabled: true
  
  config.vm.provider :libvirt do |p, override|
    p.driver = 'kvm'
    p.cpus = 2
    p.memory = 2048
    p.video_vram = 64
    #p.video_type = 'cirrus'
    p.disk_bus = 'virtio'
    p.nic_model_type = 'virtio'
    p.loader = '/usr/share/OVMF/OVMF_CODE.fd'
  end
end
EOF
  fi
  mv ${STORAGE_DIR}/${GUEST}${IMGEXT} ${STORAGE_DIR}/box.img
  (cd ${STORAGE_DIR} ; tar -cvzf ${GUEST}-${datestamp}.libvirt.box metadata.json info.json Vagrantfile `ls vmrun*` OVMF ./box.img)
  
  #pystache init/common/catalog.json.mustache "{
  #  \"author\":\"${author}\",
  #  \"guest\":\"${GUEST}\",
  #  \"datestamp\":\"${datestamp}\"
  #}" > ${STORAGE_DIR}/${GUEST}_catalog.json
#  cat << EOF >> mustache - init/common/catalog.json.mustache > ${STORAGE_DIR}/${GUEST}_catalog.json
#---
#author: ${author}
#guest: ${GUEST}
#datestamp: ${datestamp}
#---
#EOF
  erb author=${author} guest=${GUEST} datestamp=${datestamp} \
    init/common/catalog.json.erb > ${STORAGE_DIR}/${GUEST}_catalog.json
}
#------------------------------------------------

#-------------- using virtinst ------------------
import_lxc() {
  GUEST=${1:-devuan-boxe0000}
  CONNECT_OPT=${CONNECT_OPT:---connect lxc:///}
  
  virt-install ${CONNECT_OPT} --init /sbin/init --memory 768 --vcpus 1 \
    --controller virtio-serial --console pty,target_type=virtio \
    --network network=default,model=virtio-net,mac=RANDOM --boot menu=on \
    ${VIRTFS_OPTS:---filesystem type=mount,mode=passthrough,source=/mnt/Data0,target=9p_Data0} \
    --filesystem $HOME/.local/share/lxc/${GUEST}/rootfs,/ -n ${GUEST} &
  
  sleep 10 ; virsh ${CONNECT_OPT} ttyconsole ${GUEST}
  #sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > $HOME/.local/share/lxc/${GUEST}.xml
}

import_qemu() {
  GUEST=${1:-freebsd-Release-zfs}
  CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
  VUEFI_OPTS=${VUEFI_OPTS:---boot uefi}
  
  virt-install ${CONNECT_OPT} --memory 2048 --vcpus 2 \
    --controller usb,model=ehci --controller virtio-serial \
    --console pty,target_type=virtio --graphics vnc,port=-1 \
    --network network=default,model=virtio-net,mac=RANDOM \
    --boot menu=on,cdrom,hd --controller scsi,model=virtio-scsi \
    ${VIRTFS_OPTS:---filesystem type=mount,mode=passthrough,source=/mnt/Data0,target=9p_Data0} \
    --disk path=${STORAGE_DIR}/${GUEST}${IMGEXT},cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi \
    ${VUEFI_OPTS} -n ${GUEST} --import &
  
  sleep 30 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST}
  #sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > ${STORAGE_DIR}/${GUEST}.xml
}

run_virsh() {
  GUEST=${1:-freebsd-Release-zfs}
  CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
  
  ## NOTE, to convert qemu-system args to libvirt domain XML:
  #  eval "echo \"$(< vmrun_qemu.args)\"" > /tmp/run_qemu.args
  #  virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/run_qemu.args
  
  virsh ${CONNECT_OPT} start ${GUEST}
  sleep 10 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST} ; sleep 5
  virt-viewer ${CONNECT_OPT} ${GUEST} &
}
#------------------------------------------------

#------------ using qemu-system-* ---------------
run_qemu() {
  GUEST=${1:-freebsd-Release-zfs}
  QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${STORAGE_DIR}/OVMF/OVMF_CODE.fd"}
  qemu-system-x86_64 -machine accel=kvm:hvf:tcg -smp cpus=2 -m size=2048 \
    -boot order=cd,menu=on -usb -device usb-tablet \
    -net nic,model=virtio-net-pci,macaddr=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
    ${NET_OPTS:--net bridge,br=virbr0} \
    ${VIRTFS_OPTS:--virtfs local,id=fsdev0,path=/mnt/Data0,mount_tag=9p_Data0,security_model=passthrough} \
    -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
    -drive file=${STORAGE_DIR}/${GUEST}${IMGEXT},cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
    ${QUEFI_OPTS} -name ${GUEST} &
}
#------------------------------------------------

#------------------------------------------------
${@:-run_qemu freebsd-Release-zfs}
