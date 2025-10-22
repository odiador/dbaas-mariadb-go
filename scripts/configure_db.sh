#!/bin/bash

VM_IP=$1
DB_NAME=$2

if [ -z "$VM_IP" ] || [ -z "$DB_NAME" ]; then
  echo "Usage: $0 <vm_ip> <db_name>"
  exit 1
fi

# Assume SSH key or passwordless
ssh user@$VM_IP "sudo apt update && sudo apt install -y mariadb-server"
ssh user@$VM_IP "sudo systemctl start mariadb"
ssh user@$VM_IP "sudo mysql -e 'CREATE DATABASE IF NOT EXISTS $DB_NAME;'"
ssh user@$VM_IP "sudo mysql -e \"CREATE USER IF NOT EXISTS 'dbaas_user'@'%' IDENTIFIED BY 'password'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO 'dbaas_user'@'%'; FLUSH PRIVILEGES;\""

echo "MariaDB configured on $VM_IP with DB $DB_NAME"