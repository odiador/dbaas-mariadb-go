#!/bin/bash

VM_NAME=$1

if [ -z "$VM_NAME" ]; then
  echo "Usage: $0 <vm_name>"
  exit 1
fi

VBoxManage createvm --name $VM_NAME --ostype Ubuntu_64 --register
VBoxManage modifyvm $VM_NAME --memory 1024 --cpus 1
VBoxManage createhd --filename $VM_NAME.vdi --size 10000
VBoxManage storagectl $VM_NAME --name SATA --add sata
VBoxManage storageattach $VM_NAME --storagectl SATA --port 0 --device 0 --type hdd --medium $VM_NAME.vdi

echo "VM $VM_NAME created"