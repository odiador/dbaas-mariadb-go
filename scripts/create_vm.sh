#!/usr/bin/env bash

# ============================================================
# Script: Crear VM con disco multiattach y configurar MariaDB
# ============================================================
# Este script:
# - Crea una nueva VM
# - Monta el disco multiattach de la plantilla
# - Inicia la VM
# - Configura MariaDB (crea DB y usuario)
# ============================================================

set -e  # Salir si hay algún error

# If the script is executed with "sh" (dash) it can fail because
# the script uses bash-specific features (e.g. [[ ]] and read -p).
# Re-exec the script under bash to ensure compatible shell.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

# ============================================================
# Mostrar ayuda
# ============================================================
show_help() {
  cat <<EOF
Uso: $0 [opciones]

Descripción:
  Crea una nueva VM, monta el disco multiattach, inicia la VM
  y configura MariaDB con la base de datos y usuario especificados.

Opciones:
  --base-vm <nombre>         Nombre de la VM plantilla a clonar
  --vm-name <nombre>         Nombre para la nueva VM clonada
  --disk-path <ruta>         Ruta del disco VDI multiattach a montar (opcional)
  --db-name <nombre>         Nombre de la base de datos a crear
  --db-user <usuario>       Usuario de la base de datos (default: dbaas_user)
  --db-pass <password>      Contraseña del usuario (default: password)
  --vm-ip <ip>              IP de la VM (default: 192.168.56.101)
  --vm-user <usuario>       Usuario SSH de la VM (default: debian)
  --vm-password <pass>      Contraseña SSH de la VM (default: password)
  --help                    Muestra esta ayuda

Ejemplo:
  ./create_vm.sh \\
    --base-vm mariadb-template \\
    --vm-name servidor-db-1 \\
    --disk-path /home/discos/srvimg.vdi \\
    --db-name mi_base_datos \\
    --db-user mi_usuario \\
    --db-pass mi_password \\
    --vm-ip 192.168.56.102 \\
    --vm-user debian \\
    --vm-password '1234'

Requisitos:
  - VirtualBox instalado
  - Disco VDI de plantilla con MariaDB preinstalado
  - SSH configurado en la plantilla

EOF
  exit 0
}

# ============================================================
# Valores por defecto
# ============================================================
DB_USER="dbaas_user"
DB_PASS="password"
VM_IP="192.168.56.101"
VM_USER="debian"
VM_PASS="password"

# ============================================================
# Parseo de argumentos
# ============================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-vm) BASE_VM="$2"; shift 2;;
    --vm-name) VM_NAME="$2"; shift 2;;
    --disk-path) DISK_PATH="$2"; shift 2;;
    --db-name) DB_NAME="$2"; shift 2;;
    --db-user) DB_USER="$2"; shift 2;;
    --db-pass) DB_PASS="$2"; shift 2;;
    --vm-ip) VM_IP="$2"; shift 2;;
    --vm-user) VM_USER="$2"; shift 2;;
    --vm-password) VM_PASS="$2"; shift 2;;
    --help) show_help;;
    *) echo "❌ Opción desconocida: $1"; show_help;;
  esac
done

# ============================================================
# Validar parámetros obligatorios
# ============================================================
if [[ -z "$BASE_VM" || -z "$VM_NAME" || -z "$DB_NAME" ]]; then
  echo "❌ ERROR: Faltan parámetros obligatorios (--base-vm, --vm-name, --db-name)."
  echo ""
  show_help
fi

# ============================================================
# Banner inicial
# ============================================================
echo ""
echo "════════════════════════════════════════════════════════"
echo "   🖥️  CREANDO NUEVA VM PARA MARIA DB"
echo "════════════════════════════════════════════════════════"
echo "Base VM:      $BASE_VM"
echo "Nueva VM:     $VM_NAME"
echo "Disk Path:    $DISK_PATH"
echo "DB Name:      $DB_NAME"
echo "DB User:      $DB_USER"
echo "VM IP:        $VM_IP"
echo "════════════════════════════════════════════════════════"
echo ""

# ============================================================
# Paso 1: Verificar que la VM base existe
# ============================================================
echo "🔍 [1/5] Verificando VM base '$BASE_VM'..."
if ! VBoxManage showvminfo "$BASE_VM" &>/dev/null; then
  echo "❌ ERROR: La VM base '$BASE_VM' no existe."
  echo ""
  echo "VMs disponibles:"
  VBoxManage list vms
  exit 1
fi
echo "✅ VM base encontrada"
echo ""

# ============================================================
# Paso 2: Verificar disco adicional si se especificó
# ============================================================
if [[ -n "$DISK_PATH" ]]; then
  echo "🔍 [2/5] Verificando disco '$DISK_PATH'..."
  if [[ ! -f "$DISK_PATH" ]]; then
    echo "❌ ERROR: El disco '$DISK_PATH' no existe."
    exit 1
  fi
  echo "✅ Disco encontrado"
else
  echo "⏭️  [2/5] No se especificó disco adicional"
fi
echo ""

# ============================================================
# Paso 3: Verificar si la VM ya existe
# ============================================================
echo "🔍 [3/5] Verificando si '$VM_NAME' ya existe..."
if VBoxManage showvminfo "$VM_NAME" &>/dev/null; then
  echo "⚠️  La VM '$VM_NAME' ya existe."
  read -p "¿Deseas eliminarla y recrearla? (y/N): " recreate
  if [[ "$recreate" =~ ^[Yy]$ ]]; then
    echo "🗑️  Eliminando VM existente..."
    VBoxManage controlvm "$VM_NAME" poweroff 2>/dev/null || true
    VBoxManage unregistervm "$VM_NAME" --delete
    echo "✅ VM eliminada"
  else
    echo "❌ Operación cancelada"
    exit 1
  fi
fi
echo ""

# ============================================================
# Paso 4: Clonar VM
# ============================================================
echo "🌀 [4/5] Clonando VM '$VM_NAME' desde '$BASE_VM'..."
VBoxManage clonevm "$BASE_VM" --name "$VM_NAME" --register --mode machine
echo "✅ VM clonada"
echo ""

# ============================================================
# Paso 5: Montar disco adicional si se especificó
# ============================================================
if [[ -n "$DISK_PATH" ]]; then
  echo "💾 [5/5] Montando disco adicional en SATA port 0..."
  VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA" \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "$DISK_PATH" \
    --mtype multiattach
  echo "✅ Disco montado"
else
  echo "⏭️  [5/5] No se especificó disco adicional"
fi
echo ""

# ============================================================
# Paso 6: Iniciar VM y configurar MariaDB
# ============================================================
echo "🚀 [6/6] Iniciando VM '$VM_NAME'..."
VBoxManage startvm "$VM_NAME" --type headless
echo "⏳ Esperando 30 segundos para que la VM inicie..."
sleep 30

echo "⚙️  Configurando MariaDB..."
# Asumir SSH passwordless o con clave
ssh -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" << EOF
sudo systemctl start mariadb
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%'; FLUSH PRIVILEGES;"
EOF

echo "✅ MariaDB configurado"
echo ""

# ============================================================
# Resumen final
# ============================================================
echo "════════════════════════════════════════════════════════"
echo "   ✅ VM CREADA Y CONFIGURADA EXITOSAMENTE"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📋 Información:"
echo "   • VM Name:     $VM_NAME"
echo "   • IP:          $VM_IP"
echo "   • DB Name:     $DB_NAME"
echo "   • DB User:     $DB_USER"
echo ""
echo "🧪 Probar conexión:"
echo "   mysql -h $VM_IP -u $DB_USER -p$DB_PASS $DB_NAME"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""