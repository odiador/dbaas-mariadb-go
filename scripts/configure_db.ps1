<#
.SYNOPSIS
    Configurar MariaDB en VM existente

.DESCRIPTION
    Configura MariaDB en una VM existente, creando DB y usuario.

.PARAMETER VMIP
    IP de la VM

.PARAMETER DBName
    Nombre de la base de datos a crear

.PARAMETER DBUser
    Usuario de la base de datos (default: dbaas_user)

.PARAMETER DBPass
    Contraseña del usuario (default: password)

.PARAMETER VMUser
    Usuario SSH de la VM (default: debian)

.PARAMETER VMPassword
    Contraseña SSH de la VM (default: password)

.EXAMPLE
    .\configure_db.ps1 `
        -VMIP "192.168.56.102" `
        -DBName "mi_base" `
        -DBUser "mi_user" `
        -DBPass "mi_pass"

.NOTES
    Requisitos:
    - VM ejecutándose con MariaDB instalado
    - SSH configurado en la VM
    - plink.exe (PuTTY) disponible en PATH para conexiones SSH
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$VMIP,
    
    [Parameter(Mandatory=$true)]
    [string]$DBName,
    
    [Parameter(Mandatory=$false)]
    [string]$DBUser = "dbaas_user",
    
    [Parameter(Mandatory=$false)]
    [string]$DBPass = "password",
    
    [Parameter(Mandatory=$false)]
    [string]$VMUser = "debian",
    
    [Parameter(Mandatory=$false)]
    [string]$VMPassword = "password"
)

$ErrorActionPreference = "Stop"

# ============================================================
# Configurar MariaDB
# ============================================================
Write-Host "Configurando MariaDB en $VMIP..." -ForegroundColor Yellow

# Preparar comandos SQL para MariaDB
$cmd1 = 'sudo systemctl start mariadb'
$cmd2 = ('sudo mysql -e "CREATE DATABASE IF NOT EXISTS {0};"' -f $DBName)
$cmd3 = ('sudo mysql -e "CREATE USER IF NOT EXISTS ''{0}@%'' IDENTIFIED BY ''{1}''; GRANT ALL PRIVILEGES ON {2}.* TO ''{0}@%''; FLUSH PRIVILEGES;"' -f $DBUser, $DBPass, $DBName)
$sshCommands = ($cmd1, $cmd2, $cmd3) -join '; '

# Ejecutar comandos via SSH
# Intenta usar ssh (OpenSSH) primero, si no está disponible sugiere plink
try {
    # Resolver rutas exactas a los ejecutables para evitar conflictos con carpetas llamadas 'ssh'
    $sshExe = $null
    $sshCmd = Get-Command ssh.exe -ErrorAction SilentlyContinue
    if ($sshCmd -and $sshCmd.CommandType -eq 'Application') { $sshExe = $sshCmd.Source }
    if (-not $sshExe) {
        $sshCmd = Get-Command ssh -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' }
        if ($sshCmd) { $sshExe = $sshCmd.Source }
    }
    if (-not $sshExe -and (Test-Path "$env:WINDIR\System32\OpenSSH\ssh.exe")) {
        $sshExe = "$env:WINDIR\System32\OpenSSH\ssh.exe"
    }

    $plinkExe = (Get-Command plink.exe -ErrorAction SilentlyContinue).Source

    if ($sshExe) {
        # Usar OpenSSH de Windows
        $sshTarget = $VMUser + '@' + $VMIP
        & $sshExe -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $sshTarget $sshCommands 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host ("OK: MariaDB configurado en " + $VMIP + " con DB " + $DBName) -ForegroundColor Green
        } else {
            Write-Host "ERROR: No se pudo configurar MariaDB" -ForegroundColor Red
            Write-Host ("    Puedes intentar manualmente con: ssh " + $sshTarget) -ForegroundColor Yellow
            exit 1
        }
    } elseif ($plinkExe) {
        # Usar plink de PuTTY
        $sshTarget = $VMUser + '@' + $VMIP
        "y" | & $plinkExe -ssh $sshTarget -pw $VMPassword $sshCommands 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host ("OK: MariaDB configurado en " + $VMIP + " con DB " + $DBName) -ForegroundColor Green
        } else {
            Write-Host "ERROR: No se pudo configurar MariaDB" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "ERROR: No se encontro ssh ni plink.exe" -ForegroundColor Red
        Write-Host "    Instala OpenSSH de Windows o PuTTY (plink)" -ForegroundColor Yellow
        Write-Host "    OpenSSH: https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse" -ForegroundColor Yellow
        Write-Host "    PuTTY: https://www.putty.org/" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "ERROR: No se pudo ejecutar SSH" -ForegroundColor Red
    Write-Host ("    Error: " + $_) -ForegroundColor Gray
    exit 1
}
