#!/usr/bin/env bash

# ============================================================
# Script de Ejemplo: Crear VM servidor-db-1
# ============================================================
# Este script ejecuta create_vm.sh con parámetros predefinidos
# para crear la VM "servidor-db-1"
# ============================================================

# Obtener el directorio donde está este script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Creando VM servidor-db-1 con configuración predefinida..."
echo ""

# Ejecutar create_vm.sh con los parámetros
bash "$SCRIPT_DIR/create_vm.sh" \
    --base-vm maria-template \
    --vm-name servidor-db-1 \
    --disk-path '/mnt/c/Users/londg/VirtualBox VMs/maria-template/maria-template.vdi' \
    --db-name root \
    --db-user root \
    --db-pass 0112 \
    --vm-ip 192.168.56.101 \
    --vm-user londgav \
    --vm-password '0112'

exit $?
