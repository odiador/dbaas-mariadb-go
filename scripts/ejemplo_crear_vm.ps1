<#
.SYNOPSIS
    Script de ejemplo para crear VM servidor-db-1

.DESCRIPTION
    Este script ejecuta create_vm.ps1 con parámetros predefinidos
    para crear la VM "servidor-db-1"

.EXAMPLE
    .\ejemplo_crear_vm.ps1

.NOTES
    Ajusta los parámetros según tu configuración antes de ejecutar
#>

[CmdletBinding()]
param()

# Obtener el directorio donde está este script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Creando VM servidor-db-1 con configuracion predefinida..." -ForegroundColor Cyan
Write-Host ""

# Ruta al disco VDI (convertida a formato Windows)
$DiskPath = "C:\Users\londg\VirtualBox VMs\maria-template\maria-template.vdi"

# Ejecutar create_vm.ps1 con los parámetros
& "$ScriptDir\create_vm.ps1" `
    -BaseVM "maria-template" `
    -VMName "servidor-db-1" `
    -DiskPath $DiskPath `
    -DBName "root" `
    -DBUser "root" `
    -DBPass "0112" `
    -AutoDetectIP `
    -ScanRange "192.168.56.101-254" `
    -VMUser "londgav" `
    -VMPassword "0112"

exit $LASTEXITCODE
