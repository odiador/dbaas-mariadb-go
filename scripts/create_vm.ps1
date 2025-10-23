<#
.SYNOPSIS
    Crear VM con disco multiattach y configurar MariaDB

.DESCRIPTION
    Este script:
    - Crea una nueva VM
    - Monta el disco multiattach de la plantilla
    - Inicia la VM
    - Configura MariaDB (crea DB y usuario)

.PARAMETER BaseVM
    Nombre de la VM plantilla a clonar

.PARAMETER VMName
    Nombre para la nueva VM clonada

.PARAMETER DiskPath
    Ruta del disco VDI multiattach a montar (opcional)

.PARAMETER DBName
    Nombre de la base de datos a crear

.PARAMETER DBUser
    Usuario de la base de datos (default: dbaas_user)

.PARAMETER DBPass
    Contraseña del usuario (default: password)

.PARAMETER VMIP
    IP de la VM (default: 192.168.56.101)

.PARAMETER VMUser
    Usuario SSH de la VM (default: debian)

.PARAMETER VMPassword
    Contraseña SSH de la VM (default: password)

.EXAMPLE
    .\create_vm.ps1 `
        -BaseVM "mariadb-template" `
        -VMName "servidor-db-1" `
        -DiskPath "C:\discos\srvimg.vdi" `
        -DBName "mi_base_datos" `
        -DBUser "mi_usuario" `
        -DBPass "mi_password" `
        -VMIP "192.168.56.102" `
        -VMUser "debian" `
        -VMPassword "1234"

.NOTES
    Requisitos:
    - VirtualBox instalado
    - Disco VDI de plantilla con MariaDB preinstalado
    - SSH configurado en la plantilla
    - plink.exe (PuTTY) disponible en PATH para conexiones SSH
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$BaseVM,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    
    [Parameter(Mandatory=$false)]
    [string]$DiskPath,
    
    [Parameter(Mandatory=$true)]
    [string]$DBName,
    
    [Parameter(Mandatory=$false)]
    [string]$DBUser = "dbaas_user",
    
    [Parameter(Mandatory=$false)]
    [string]$DBPass = "password",
    
    [Parameter(Mandatory=$false)]
    [string]$VMIP = "192.168.56.101",
    
    [Parameter(Mandatory=$false)]
    [string]$VMUser = "debian",
    
    [Parameter(Mandatory=$false)]
    [string]$VMPassword = "password"
    ,
    [Parameter(Mandatory=$false)]
    [switch]$AutoDetectIP,
    [Parameter(Mandatory=$false)]
    [string]$ScanRange
)

$ErrorActionPreference = "Stop"

# ============================================================
# Helpers: Obtener IP de la VM automaticamente
# ============================================================
function Redact {
    param(
        [string]$Text,
        [string]$Secret
    )
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    if ([string]::IsNullOrEmpty($Secret)) { return $Text }
    try { return ($Text -replace [regex]::Escape($Secret), '***') } catch { return $Text }
}
function Get-VMIPv4 {
    param(
        [string]$VMName,
        [int]$TimeoutSec = 60,
        [string]$ScanRange
    )

    # 1) Intentar obtener IP via Guest Additions (guestproperty) solo si NO se especifico ScanRange
    if (-not $ScanRange) {
        Write-Host "DEBUG: Intentando Guest Additions (guestproperty) para obtener IP..." -ForegroundColor DarkGray
        $start = Get-Date
        while ((Get-Date) - $start -lt [TimeSpan]::FromSeconds($TimeoutSec)) {
            for ($i = 0; $i -lt 4; $i++) {
                try {
                    $gp = & VBoxManage guestproperty get "$VMName" "/VirtualBox/GuestInfo/Net/$i/V4/IP" 2>$null
                    if ($LASTEXITCODE -eq 0 -and $gp -and ($gp -match "Value:\s*(\d+\.\d+\.\d+\.\d+)")) {
                        Write-Host ("DEBUG: IP obtenida por guestproperty en interfaz $i : " + $Matches[1]) -ForegroundColor DarkGray
                        return $Matches[1]
                    }
                } catch { }
            }
            Start-Sleep -Milliseconds 800
        }
        Write-Host "DEBUG: Guest Additions no devolvio IP a tiempo" -ForegroundColor DarkGray
    } else {
        Write-Host "DEBUG: Omitiendo Guest Additions por ScanRange especificado" -ForegroundColor DarkGray
    }

    # 2) Si no hay Guest Additions: usar rango provisto o buscar por MAC en red Host-Only
    try {
        # Si se provee un rango, construir lista de hosts a partir de este
        $hosts = @()
        if ($ScanRange -and ($ScanRange -match '^(\d+\.\d+\.\d+)\.(\d+)-(\d+)$')) {
            $base3 = $Matches[1]
            $startHost = [int]$Matches[2]
            $endHost = [int]$Matches[3]
            if ($startHost -gt $endHost) { $t = $startHost; $startHost = $endHost; $endHost = $t }
            $startHost = [Math]::Max(1, [Math]::Min(254, $startHost))
            $endHost = [Math]::Max(1, [Math]::Min(254, $endHost))
            for ($h = $startHost; $h -le $endHost; $h++) { $hosts += "$base3.$h" }
            Write-Host ("DEBUG: Usando ScanRange $ScanRange => total hosts: " + $hosts.Count) -ForegroundColor DarkGray
        }

        $info = & VBoxManage showvminfo "$VMName" --machinereadable 2>$null
        if (-not $info) { return $null }

        $nic1 = ($info | Where-Object { $_ -match '^nic1="(.+)"' } | ForEach-Object { [regex]::Match($_, 'nic1="([^"]+)"').Groups[1].Value })
        $hostOnlyAdapter = ($info | Where-Object { $_ -match '^hostonlyadapter1="(.+)"' } | ForEach-Object { [regex]::Match($_, 'hostonlyadapter1="([^"]+)"').Groups[1].Value })
        $macRaw = ($info | Where-Object { $_ -match '^macaddress1="?([A-Fa-f0-9]{12})' } | ForEach-Object { [regex]::Match($_, 'macaddress1="?([A-Fa-f0-9]{12})').Groups[1].Value })

        if (-not $macRaw) { return $null }
        $macFormatted = ($macRaw.ToUpper() -replace '(.{2})(?!$)', '$1-')
        Write-Host ("DEBUG: nic1=$nic1 adapter=$hostOnlyAdapter mac=$macFormatted") -ForegroundColor DarkGray

        # 2.1) Metodo rapido: consultar lease del DHCP de VirtualBox por MAC
        try {
            if ($hostOnlyAdapter) {
                $leaseOut = & VBoxManage dhcpserver findlease --network "$hostOnlyAdapter" --mac-address "$macRaw" 2>$null
                if ($LASTEXITCODE -eq 0 -and $leaseOut) {
                    $leaseIP = ($leaseOut | Select-String -Pattern '(\d+\.\d+\.\d+\.\d+)' -AllMatches | ForEach-Object { $_.Matches } | Select-Object -First 1).Value
                    if ($leaseIP) {
                        Write-Host ("DEBUG: IP encontrada por DHCP lease: " + $leaseIP) -ForegroundColor DarkGray
                        return $leaseIP
                    }
                }
            }
        } catch { }

        if (-not $hosts -or $hosts.Count -eq 0) {
            # Solo intentamos host-only si nic1 es hostonly y tenemos nombre del adaptador
            if ($nic1 -ne 'hostonly' -or -not $hostOnlyAdapter) { return $null }

            $hifs = & VBoxManage list hostonlyifs 2>$null
            if (-not $hifs) { return $null }

            # Extraer bloque del adaptador host-only correspondiente
            $block = @()
            $collect = $false
            foreach ($line in $hifs) {
                if ($line -match '^Name:\s*(.+)$') {
                    $collect = ($Matches[1].Trim() -eq $hostOnlyAdapter)
                    $block = @()
                }
                if ($collect) { $block += $line }
            }

            if (-not $block -or $block.Count -eq 0) { return $null }

            $ipLine = $block | Where-Object { $_ -match '^IP Address:\s*(\d+\.\d+\.\d+\.\d+)' }
            $maskLine = $block | Where-Object { $_ -match '^Network Mask:\s*(\d+\.\d+\.\d+\.\d+)' }
            if (-not $ipLine -or -not $maskLine) { return $null }
            $hostIP = [regex]::Match($ipLine, '(\d+\.\d+\.\d+\.\d+)').Value
            $maskIP = [regex]::Match($maskLine, '(\d+\.\d+\.\d+\.\d+)').Value
            Write-Host ("DEBUG: Host-only gateway=$hostIP mask=$maskIP") -ForegroundColor DarkGray

            # Calcular red
            function ToBytes($ip) { return $ip.Split('.') | ForEach-Object {[int]$_} }
            $ipB = ToBytes $hostIP
            $maskB = ToBytes $maskIP
            $netB = for ($i=0;$i -lt 4;$i++){ $ipB[$i] -band $maskB[$i] }
            $networkBase = ($netB -join '.')

            # Asumir /24 si mascara es 255.255.255.0, sino limitar a 254 hosts
            $is24 = ($maskIP -eq '255.255.255.0')
            if ($is24) {
                $base3 = ($networkBase.Split('.')[0..2] -join '.')
                for ($h=2; $h -lt 255; $h++) { $hosts += "$base3.$h" }
            } else {
                # Fallback simple: probar los 254 hosts siguientes al host gateway
                $base3 = ($networkBase.Split('.')[0..2] -join '.')
                for ($h=2; $h -lt 255; $h++) { $hosts += "$base3.$h" }
            }
            Write-Host ("DEBUG: Hosts a escanear en host-only: " + $hosts.Count) -ForegroundColor DarkGray
        }

        # Hacer ping rapido para poblar ARP
        Write-Host "DEBUG: Realizando ping rapido para poblar ARP..." -ForegroundColor DarkGray
        $i = 0
        foreach ($ip in $hosts) {
            cmd /c "ping -n 1 -w 300 $ip" *> $null
            $i++
            if (($i % 25) -eq 0) { Write-Host ("DEBUG: Ping " + $i + "/" + $hosts.Count) -ForegroundColor DarkGray }
        }

        # Buscar IP por direccion MAC en vecindarios
        Write-Host "DEBUG: Consultando Get-NetNeighbor por MAC..." -ForegroundColor DarkGray
        $neighbor = Get-NetNeighbor -AddressFamily IPv4 | Where-Object { $_.LinkLayerAddress -ieq $macFormatted }
        if ($neighbor -and $neighbor.IPAddress) {
            Write-Host ("DEBUG: IP encontrada por vecinos: " + $neighbor.IPAddress) -ForegroundColor DarkGray
            return $neighbor.IPAddress
        }

        # Como ultimo recurso, parsear arp -a
        Write-Host "DEBUG: Analizando salida de arp -a..." -ForegroundColor DarkGray
        $arp = cmd /c arp -a
        foreach ($line in $arp) {
            if ($line -match '^(\d+\.\d+\.\d+\.\d+)\s+([\da-fA-F\-]{17})') {
                $ip = $Matches[1]; $mac = $Matches[2]
                if ($mac -replace '-', '' -ieq $macRaw) {
                    Write-Host ("DEBUG: IP encontrada por ARP: " + $ip) -ForegroundColor DarkGray
                    return $ip
                }
            }
        }
    } catch { }

    return $null
}

# ============================================================
# Banner inicial
# ============================================================
Write-Host ""
Write-Host "========================================================="
Write-Host "   CREANDO NUEVA VM PARA MARIA DB" -ForegroundColor Cyan
Write-Host "========================================================="
Write-Host "Base VM:      $BaseVM"
Write-Host "Nueva VM:     $VMName"
Write-Host "Disk Path:    $DiskPath"
Write-Host "DB Name:      $DBName"
Write-Host "DB User:      $DBUser"
Write-Host "VM IP:        $VMIP"
Write-Host "========================================================="
Write-Host ""

# ============================================================
# Paso 1: Verificar que la VM base existe
# ============================================================
Write-Host "[1/5] Verificando VM base '$BaseVM'..." -ForegroundColor Yellow
$baseExists = $false
try {
    & VBoxManage showvminfo "$BaseVM" *> $null
    $baseExists = ($LASTEXITCODE -eq 0)
} catch {
    $baseExists = $false
}
if (-not $baseExists) {
    Write-Host "ERROR: La VM base '$BaseVM' no existe." -ForegroundColor Red
    Write-Host ""
    Write-Host "VMs disponibles:"
    VBoxManage list vms
    exit 1
}
Write-Host "OK: VM base encontrada" -ForegroundColor Green
Write-Host ""

# ============================================================
# Paso 2: Verificar disco adicional si se especificó
# ============================================================
if ($DiskPath) {
    Write-Host "[2/5] Verificando disco '$DiskPath'..." -ForegroundColor Yellow
    if (-not (Test-Path $DiskPath)) {
        Write-Host "ERROR: El disco '$DiskPath' no existe." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: Disco encontrado" -ForegroundColor Green
} else {
    Write-Host "[2/5] No se especifico disco adicional" -ForegroundColor Gray
}
Write-Host ""

# ============================================================
# Paso 3: Verificar si la VM ya existe
# ============================================================
Write-Host "[3/5] Verificando si '$VMName' ya existe..." -ForegroundColor Yellow
$vmExists = $false
try {
    & VBoxManage showvminfo "$VMName" *> $null
    $vmExists = ($LASTEXITCODE -eq 0)
} catch {
    $vmExists = $false
}
if ($vmExists) {
    Write-Host "ADVERTENCIA: La VM '$VMName' ya existe." -ForegroundColor Yellow
    $recreate = Read-Host "Deseas eliminarla y recrearla? (y/N)"
    if ($recreate -match '^[Yy]$') {
        Write-Host "Eliminando VM existente..." -ForegroundColor Yellow
        VBoxManage controlvm "$VMName" poweroff 2>$null
        VBoxManage unregistervm "$VMName" --delete
        Write-Host "OK: VM eliminada" -ForegroundColor Green
    } else {
        Write-Host "Operacion cancelada" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# ============================================================
# Paso 4: Clonar VM
# ============================================================
Write-Host "[4/5] Clonando VM '$VMName' desde '$BaseVM'..." -ForegroundColor Yellow
VBoxManage clonevm "$BaseVM" --name "$VMName" --register --mode machine
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No se pudo clonar la VM" -ForegroundColor Red
    exit 1
}
Write-Host "OK: VM clonada" -ForegroundColor Green
Write-Host ""

# ============================================================
# Paso 5: Montar disco adicional si se especificó
# ============================================================
if ($DiskPath) {
    Write-Host "[5/5] Montando disco adicional en SATA port 1..." -ForegroundColor Yellow
    VBoxManage storageattach "$VMName" `
        --storagectl "SATA" `
        --port 1 `
        --device 0 `
        --type hdd `
        --medium "$DiskPath" `
        --mtype multiattach
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: No se pudo montar el disco" -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: Disco montado" -ForegroundColor Green
} else {
    Write-Host "[5/5] No se especifico disco adicional" -ForegroundColor Gray
}
Write-Host ""

# ============================================================
# Paso 6: Iniciar VM y configurar MariaDB
# ============================================================
Write-Host "[6/6] Iniciando VM '$VMName'..." -ForegroundColor Yellow
VBoxManage startvm "$VMName" --type headless
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No se pudo iniciar la VM" -ForegroundColor Red
    exit 1
}
Write-Host "Esperando 30 segundos para que la VM inicie..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "Configurando MariaDB..." -ForegroundColor Yellow

# Si se solicita, detectar automaticamente la IP asignada por DHCP
if ($AutoDetectIP -or ($VMIP -eq 'auto') -or (-not $VMIP)) {
    Write-Host "Detectando IP de la VM asignada por DHCP..." -ForegroundColor Yellow
    $detected = Get-VMIPv4 -VMName $VMName -TimeoutSec 60 -ScanRange $ScanRange
    if ($detected) {
        $VMIP = $detected
        Write-Host ("IP detectada: " + $VMIP) -ForegroundColor Green
    } else {
        Write-Host "No se pudo detectar la IP automaticamente. Se usara el valor de VMIP proporcionado." -ForegroundColor Yellow
    }
}

# Preparar script remoto (codificado en Base64) para ejecutar en la VM
    $userAtHost = $DBUser + '@%'
    $remoteScript = @"
PASS='$VMPassword'
echo "$PASS" | sudo -S systemctl start mariadb
echo "$PASS" | sudo -S mysql -e "CREATE DATABASE IF NOT EXISTS $DBName;"
echo "$PASS" | sudo -S mysql -e "CREATE USER IF NOT EXISTS '$userAtHost' IDENTIFIED BY '$DBPass'; GRANT ALL PRIVILEGES ON $DBName.* TO '$userAtHost'; FLUSH PRIVILEGES;"
"@
    $remoteBytes = [System.Text.Encoding]::UTF8.GetBytes($remoteScript)
    $remoteB64 = [Convert]::ToBase64String($remoteBytes)
    $remoteCommand = "echo $remoteB64 | base64 -d | bash"

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
    Write-Host ("DEBUG: ssh.exe: " + $sshExe) -ForegroundColor DarkGray
    Write-Host ("DEBUG: ssh target: " + $sshTarget) -ForegroundColor DarkGray
    Write-Host ("DEBUG: remote script size (bytes): " + $remoteBytes.Length) -ForegroundColor DarkGray
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $sshOutput = & $sshExe -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL $sshTarget $remoteCommand 2>&1
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $prevEAP
        if ($exitCode -eq 0) {
            Write-Host "OK: MariaDB configurado" -ForegroundColor Green
        } else {
            Write-Host "ADVERTENCIA: Hubo un problema configurando MariaDB" -ForegroundColor Yellow
            if ($sshOutput) { Write-Host ("DEBUG ssh output: " + ($sshOutput -join " ")) -ForegroundColor DarkGray }
            Write-Host ("    Puedes configurarlo manualmente con: ssh " + $sshTarget) -ForegroundColor Yellow
        }
    } elseif ($plinkExe) {
        # Usar plink de PuTTY
        $sshTarget = $VMUser + '@' + $VMIP
    Write-Host ("DEBUG: plink.exe: " + $plinkExe) -ForegroundColor DarkGray
    Write-Host ("DEBUG: ssh target: " + $sshTarget) -ForegroundColor DarkGray
    Write-Host ("DEBUG: remote script size (bytes): " + $remoteBytes.Length) -ForegroundColor DarkGray
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $plinkOutput = "y" | & $plinkExe -ssh $sshTarget -pw $VMPassword $remoteCommand 2>&1
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $prevEAP
        if ($exitCode -eq 0) {
            Write-Host "OK: MariaDB configurado" -ForegroundColor Green
        } else {
            Write-Host "ADVERTENCIA: Hubo un problema configurando MariaDB" -ForegroundColor Yellow
            if ($plinkOutput) { Write-Host ("DEBUG plink output: " + ($plinkOutput -join " ")) -ForegroundColor DarkGray }
        }
    } else {
        Write-Host "ADVERTENCIA: No se encontro ssh ni plink.exe" -ForegroundColor Yellow
        Write-Host "    Instala OpenSSH de Windows o PuTTY (plink)" -ForegroundColor Yellow
        Write-Host "    Puedes configurar MariaDB manualmente conectandote por SSH" -ForegroundColor Yellow
    }
} catch {
    Write-Host "ADVERTENCIA: No se pudo ejecutar SSH" -ForegroundColor Yellow
    Write-Host ("    Error: " + $_) -ForegroundColor Gray
    Write-Host "    Puedes configurar MariaDB manualmente conectandote por SSH" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# Resumen final
# ============================================================
Write-Host "========================================================="
Write-Host "   VM CREADA Y CONFIGURADA EXITOSAMENTE" -ForegroundColor Green
Write-Host "========================================================="
Write-Host ""
Write-Host "Informacion:"
Write-Host "   - VM Name:     $VMName"
Write-Host "   - IP:          $VMIP"
Write-Host "   - DB Name:     $DBName"
Write-Host "   - DB User:     $DBUser"
Write-Host ""
Write-Host "Probar conexion:"
Write-Host "   mysql -h $VMIP -u $DBUser -p$DBPass $DBName" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================================="
Write-Host ""
