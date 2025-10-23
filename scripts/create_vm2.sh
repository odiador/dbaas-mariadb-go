#!/usr/bin/env bash

# ============================================================
# Script: Crear VM con disco multiattach y configurar MariaDB
# ============================================================
# Este script:
# - Crea una nueva VM
# - Monta el disco multiattach de la plantilla
# - Inicia la VM
# - Detecta IP automáticamente con nmap (si se especifica)
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
# Función para detectar IP de una VM en la red host-only (adaptado de add_server.sh)
# ============================================================
detect_vm_ip() {
  local vm_name="$1"
  local network_range="$2"
  local timeout="$3"
  local vm_user="$4"
  local vm_pass="$5"
  
  # Todos los mensajes informativos van a stderr (>&2)
  echo "🔍 Detectando IP de la VM $vm_name en la red $network_range ..." >&2
  echo "   Esperando $timeout segundos para que la VM obtenga IP por DHCP..." >&2
  sleep "$timeout"
  echo "" >&2
  
  # Verificar que nmap esté disponible
  if ! command -v nmap &>/dev/null; then
    echo "❌ ERROR: nmap no está instalado. Instálalo con: sudo pacman -S nmap" >&2
    return 1
  fi
  
  # Intentar detectar con nmap (máximo 5 intentos)
  local max_attempts=5
  local attempt=1
  
  # Extraer el prefijo de red (ej: de "192.168.56.102-254" obtener "192.168.56")
  local network_prefix=$(echo "$network_range" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')
  
  while [ $attempt -le $max_attempts ]; do
    echo "   📡 Intento $attempt/$max_attempts: Escaneando rango DHCP con nmap ($network_range)..." >&2
    
    # Escanear red y obtener todas las IPs activas
    local nmap_output=$(nmap -sn "$network_range" 2>/dev/null)
    
    # Extraer IPs del output usando grep con regex
    # Formato: "Nmap scan report for 192.168.56.114" o "Nmap scan report for 192.168.56.114 (192.168.56.114)"
    local all_ips=$(echo "$nmap_output" | \
      grep "Nmap scan report for" | \
      grep -oE "$network_prefix\.[0-9]+" | \
      sort -u)
    
    if [[ -n "$all_ips" ]]; then
      # Convertir a array para iterar correctamente
      local ips_array=()
      while IFS= read -r line; do
        [[ -n "$line" ]] && ips_array+=("$line")
      done <<< "$all_ips"
      
      local ip_count=${#ips_array[@]}
      echo "   📋 Se encontraron $ip_count host(s) activo(s), verificando hostnames..." >&2
      echo "   📝 IPs: ${ips_array[*]}" >&2
      
      # Verificar hostname de cada IP
      for ip in "${ips_array[@]}"; do
        echo "   🔍 Verificando $ip..." >&2
        
        # Intentar obtener hostname via SSH (asumiendo clave SSH sin password; si no, usar sshpass)
        local hostname=$(ssh \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o LogLevel=ERROR \
          -o ConnectTimeout=3 \
          -o BatchMode=no \
          "${vm_user}@${ip}" "hostname; echo" 2>/dev/null | tr -d '\r\n\t ')
        
        if [[ "$hostname" == "$vm_name" ]]; then
          echo "✅ IP detectada: $ip (hostname: $hostname)" >&2
          echo "$ip"  # Solo esto va a stdout
          return 0
        else
          echo "   ⏭️  Saltando $ip (hostname: ${hostname:-sin acceso SSH})" >&2
        fi
      done
      
      echo "   ⚠️  No se encontró ninguna VM con hostname '$vm_name' en este intento" >&2
    else
      echo "   ⚠️  No se encontraron hosts activos con nmap" >&2
    fi
    
    # Si no es el último intento, esperar antes de reintentar
    if [ $attempt -lt $max_attempts ]; then
      echo "   ⏳ Esperando 5 segundos antes de reintentar..." >&2
      sleep 5
    fi
    
    attempt=$((attempt + 1))
  done
  
  echo "❌ No se pudo detectar la IP después de $max_attempts intentos" >&2
  return 1
}

# ============================================================
# Mostrar ayuda
# ============================================================
show_help() {
  cat <<EOF
Uso: $0 [opciones]

Descripción:
  Crea una nueva VM, monta el disco multiattach, inicia la VM,
  detecta IP automáticamente con nmap (si se especifica), y configura MariaDB.

Opciones:
  --base-vm <nombre>         Nombre de la VM plantilla a clonar
  --vm-name <nombre>         Nombre para la nueva VM clonada
  --disk-path <ruta>         Ruta del disco VDI multiattach a montar (opcional)
  --db-name <nombre>         Nombre de la base de datos a crear
  --db-user <usuario>       Usuario de la base de datos (default: dbaas_user)
  --db-pass <password>      Contraseña del usuario (default: password)
  --vm-ip <ip|auto>         IP de la VM (default: 192.168.56.101) o 'auto' para detectar automáticamente
  --vm-user <usuario>       Usuario SSH de la VM (default: debian)
  --vm-password <pass>      Contraseña SSH de la VM (default: password)
  --network-range <rango>   Rango de red para detección automática (ej: 192.168.56.102-254, requerido si --vm-ip=auto)
  --timeout <segundos>      Timeout para detectar IP (default: 30)
  --help                    Muestra esta ayuda

Ejemplo:
  ./create_vm.sh \\
    --base-vm mariadb-template \\
    --vm-name servidor-db-1 \\
    --disk-path /home/discos/srvimg.vdi \\
    --db-name mi_base_datos \\
    --db-user mi_usuario \\
    --db-pass mi_password \\
    --vm-ip auto \\
    --network-range 192.168.56.102-254 \\
    --vm-user debian \\
    --vm-password '1234'

Requisitos:
  - VirtualBox instalado
  - Disco VDI de plantilla con MariaDB preinstalado
  - SSH configurado en la plantilla (clave sin password recomendada)
  - nmap para detección automática: sudo pacman -S nmap

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
TIMEOUT=30

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
    --network-range) NETWORK_RANGE="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
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

if [[ "$VM_IP" == "auto" && -z "$NETWORK_RANGE" ]]; then
  echo "❌ ERROR: Si --vm-ip=auto, debes especificar --network-range."
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
if [[ "$VM_IP" == "auto" ]]; then
  echo "Network Range: $NETWORK_RANGE"
fi
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

# Detectar IP automáticamente si se especificó
if [[ "$VM_IP" == "auto" ]]; then
  echo "🔍 Detectando IP de la VM..."
  DETECTED_IP=$(detect_vm_ip "$VM_NAME" "$NETWORK_RANGE" "$TIMEOUT" "$VM_USER" "$VM_PASS")
  if [[ -z "$DETECTED_IP" ]]; then
    echo ""
    echo "❌ No se pudo detectar la IP automáticamente."
    echo ""
    echo "Opciones:"
    echo "  1. Espera más tiempo y vuelve a ejecutar el script"
    echo "  2. Instala nmap si no está disponible"
    echo ""
    read -p "¿Deseas ingresar la IP manualmente? (y/N): " manual_ip
    if [[ "$manual_ip" =~ ^[Yy]$ ]]; then
      read -p "Ingresa la IP de la VM: " DETECTED_IP
      if [[ -z "$DETECTED_IP" ]]; then
        echo "❌ IP no válida"
        exit 1
      fi
    else
      echo "❌ Operación cancelada"
      exit 1
    fi
  fi
  VM_IP="$DETECTED_IP"
  echo "✅ IP detectada/configurada: $VM_IP"
  echo ""
fi

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