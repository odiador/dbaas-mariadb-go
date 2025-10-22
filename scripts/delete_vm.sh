#!/bin/bash

VM_NAME=$1

if [ -z "$VM_NAME" ]; then
  echo "Usage: $0 <vm_name>"
  exit 1
fi

VBoxManage controlvm $VM_NAME poweroff
VBoxManage unregistervm $VM_NAME --delete

echo "VM $VM_NAME deleted"