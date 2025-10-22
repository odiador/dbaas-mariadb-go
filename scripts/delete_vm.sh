#!/bin/bash

# ============================================================
# Script: Eliminar VM
# ============================================================

set -e

# ============================================================
# Mostrar ayuda
# ============================================================
show_help() {
  cat <<EOF
Uso: $0 [opciones]

Descripción:
  Elimina una VM existente.

Opciones:
  --vm-name <nombre>        Nombre de la VM a eliminar
  --help                    Muestra esta ayuda

Ejemplo:
  ./delete_vm.sh --vm-name servidor-db-1

EOF
  exit 0
}

# ============================================================
# Parseo de argumentos
# ============================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm-name) VM_NAME="$2"; shift 2;;
    --help) show_help;;
    *) echo "❌ Opción desconocida: $1"; show_help;;
  esac
done

# ============================================================
# Validar parámetros
# ============================================================
if [[ -z "$VM_NAME" ]]; then
  echo "❌ ERROR: Falta --vm-name."
  show_help
fi

# ============================================================
# Eliminar VM
# ============================================================
echo "🗑️  Eliminando VM '$VM_NAME'..."

VBoxManage controlvm "$VM_NAME" poweroff 2>/dev/null || true
VBoxManage unregistervm "$VM_NAME" --delete

echo "✅ VM '$VM_NAME' eliminada"