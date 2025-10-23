<#
.SYNOPSIS
    Eliminar VM

.DESCRIPTION
    Elimina una VM existente de VirtualBox.

.PARAMETER VMName
    Nombre de la VM a eliminar

.EXAMPLE
    .\delete_vm.ps1 -VMName "servidor-db-1"

.NOTES
    Requisitos:
    - VirtualBox instalado
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$VMName
)

$ErrorActionPreference = "Stop"

# ============================================================
# Eliminar VM
# ============================================================
Write-Host "🗑️  Eliminando VM '$VMName'..." -ForegroundColor Yellow

# Intentar apagar la VM si está encendida
VBoxManage controlvm "$VMName" poweroff 2>$null

# Esperar un momento para que se apague completamente
Start-Sleep -Seconds 2

# Eliminar la VM
VBoxManage unregistervm "$VMName" --delete

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ VM '$VMName' eliminada" -ForegroundColor Green
} else {
    Write-Host "❌ ERROR: No se pudo eliminar la VM '$VMName'" -ForegroundColor Red
    exit 1
}
