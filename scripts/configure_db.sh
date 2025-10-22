#!/bin/bash

# ============================================================
# Script: Configurar MariaDB en VM existente
# ============================================================

set -e

# ============================================================
# Mostrar ayuda
# ============================================================
show_help() {
  cat <<EOF
Uso: $0 [opciones]

Descripción:
  Configura MariaDB en una VM existente, creando DB y usuario.

Opciones:
  --vm-ip <ip>              IP de la VM
  --db-name <nombre>        Nombre de la base de datos a crear
  --db-user <usuario>       Usuario de la base de datos (default: dbaas_user)
  --db-pass <password>      Contraseña del usuario (default: password)
  --vm-user <usuario>       Usuario SSH de la VM (default: debian)
  --vm-password <pass>      Contraseña SSH de la VM (default: password)
  --help                    Muestra esta ayuda

Ejemplo:
  ./configure_db.sh \\
    --vm-ip 192.168.56.102 \\
    --db-name mi_base \\
    --db-user mi_user \\
    --db-pass mi_pass

EOF
  exit 0
}

# ============================================================
# Valores por defecto
# ============================================================
DB_USER="dbaas_user"
DB_PASS="password"
VM_USER="debian"
VM_PASS="password"

# ============================================================
# Parseo de argumentos
# ============================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm-ip) VM_IP="$2"; shift 2;;
    --db-name) DB_NAME="$2"; shift 2;;
    --db-user) DB_USER="$2"; shift 2;;
    --db-pass) DB_PASS="$2"; shift 2;;
    --vm-user) VM_USER="$2"; shift 2;;
    --vm-password) VM_PASS="$2"; shift 2;;
    --help) show_help;;
    *) echo "❌ Opción desconocida: $1"; show_help;;
  esac
done

# ============================================================
# Validar parámetros
# ============================================================
if [[ -z "$VM_IP" || -z "$DB_NAME" ]]; then
  echo "❌ ERROR: Faltan --vm-ip y --db-name."
  show_help
fi

# ============================================================
# Configurar MariaDB
# ============================================================
echo "⚙️  Configurando MariaDB en $VM_IP..."

ssh -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" << EOF
sudo systemctl start mariadb
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%'; FLUSH PRIVILEGES;"
EOF

echo "✅ MariaDB configurado en $VM_IP con DB $DB_NAME"