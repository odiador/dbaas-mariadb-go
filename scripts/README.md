# Scripts de Gestión de VMs para MariaDB

Este directorio contiene scripts para automatizar la creación, configuración y eliminación de máquinas virtuales con MariaDB en VirtualBox.

## 📁 Contenido

### Scripts Bash (para Linux/WSL/macOS)
- `create_vm.sh` - Crear VM con disco multiattach y configurar MariaDB
- `configure_db.sh` - Configurar MariaDB en VM existente
- `delete_vm.sh` - Eliminar VM

### Scripts PowerShell (para Windows)
- `create_vm.ps1` - Crear VM con disco multiattach y configurar MariaDB
- `configure_db.ps1` - Configurar MariaDB en VM existente
- `delete_vm.ps1` - Eliminar VM

## 🔧 Requisitos

### Para todos los scripts
- **VirtualBox** instalado y `VBoxManage` disponible en PATH
- Una VM plantilla con **MariaDB** preinstalado
- **SSH** configurado en la VM plantilla

### Adicional para scripts PowerShell
- **plink.exe** (parte de PuTTY) para conexiones SSH desde Windows
  - Descargar desde: https://www.putty.org/
  - Agregar al PATH de Windows o colocar en la misma carpeta que los scripts

### Adicional para scripts Bash en WSL
- Scripts deben tener permisos de ejecución: `chmod +x *.sh`
- Ejecutar con bash: `bash create_vm.sh` o `./create_vm.sh`

## 📖 Uso

### Windows (PowerShell)

#### Crear una nueva VM

```powershell
.\create_vm.ps1 `
    -BaseVM "mariadb-template" `
    -VMName "servidor-db-1" `
    -DBName "mi_base_datos" `
    -DBUser "mi_usuario" `
    -DBPass "mi_password" `
    -VMIP "192.168.56.102" `
    -VMUser "debian" `
    -VMPassword "1234"
```

**Con disco adicional:**

```powershell
.\create_vm.ps1 `
    -BaseVM "mariadb-template" `
    -VMName "servidor-db-1" `
    -DiskPath "C:\discos\srvimg.vdi" `
    -DBName "mi_base_datos"
```

#### Configurar MariaDB en VM existente

```powershell
.\configure_db.ps1 `
    -VMIP "192.168.56.102" `
    -DBName "mi_nueva_base" `
    -DBUser "usuario" `
    -DBPass "password"
```

#### Eliminar una VM

```powershell
.\delete_vm.ps1 -VMName "servidor-db-1"
```

#### Ver ayuda de un script

```powershell
Get-Help .\create_vm.ps1 -Detailed
```

---

### Linux / macOS / WSL (Bash)

#### Crear una nueva VM

```bash
bash create_vm.sh \
    --base-vm mariadb-template \
    --vm-name servidor-db-1 \
    --db-name mi_base_datos \
    --db-user mi_usuario \
    --db-pass mi_password \
    --vm-ip 192.168.56.102 \
    --vm-user debian \
    --vm-password '1234'
```

**Con disco adicional:**

```bash
bash create_vm.sh \
    --base-vm mariadb-template \
    --vm-name servidor-db-1 \
    --disk-path /home/discos/srvimg.vdi \
    --db-name mi_base_datos
```

#### Configurar MariaDB en VM existente

```bash
bash configure_db.sh \
    --vm-ip 192.168.56.102 \
    --db-name mi_nueva_base \
    --db-user usuario \
    --db-pass password
```

#### Eliminar una VM

```bash
bash delete_vm.sh --vm-name servidor-db-1
```

#### Ver ayuda de un script

```bash
bash create_vm.sh --help
```

---

## ⚙️ Parámetros y Valores por Defecto

### create_vm (ambas versiones)

| Parámetro | Bash | PowerShell | Requerido | Default | Descripción |
|-----------|------|------------|-----------|---------|-------------|
| Base VM | `--base-vm` | `-BaseVM` | ✅ | - | VM plantilla a clonar |
| VM Name | `--vm-name` | `-VMName` | ✅ | - | Nombre de la nueva VM |
| DB Name | `--db-name` | `-DBName` | ✅ | - | Nombre de la base de datos |
| Disk Path | `--disk-path` | `-DiskPath` | ❌ | - | Ruta del disco VDI multiattach |
| DB User | `--db-user` | `-DBUser` | ❌ | dbaas_user | Usuario de MariaDB |
| DB Pass | `--db-pass` | `-DBPass` | ❌ | password | Contraseña de MariaDB |
| VM IP | `--vm-ip` | `-VMIP` | ❌ | 192.168.56.101 | IP de la VM |
| VM User | `--vm-user` | `-VMUser` | ❌ | debian | Usuario SSH |
| VM Password | `--vm-password` | `-VMPassword` | ❌ | password | Contraseña SSH |

### configure_db (ambas versiones)

| Parámetro | Bash | PowerShell | Requerido | Default | Descripción |
|-----------|------|------------|-----------|---------|-------------|
| VM IP | `--vm-ip` | `-VMIP` | ✅ | - | IP de la VM |
| DB Name | `--db-name` | `-DBName` | ✅ | - | Nombre de la base de datos |
| DB User | `--db-user` | `-DBUser` | ❌ | dbaas_user | Usuario de MariaDB |
| DB Pass | `--db-pass` | `-DBPass` | ❌ | password | Contraseña de MariaDB |
| VM User | `--vm-user` | `-VMUser` | ❌ | debian | Usuario SSH |
| VM Password | `--vm-password` | `-VMPassword` | ❌ | password | Contraseña SSH |

### delete_vm (ambas versiones)

| Parámetro | Bash | PowerShell | Requerido | Default | Descripción |
|-----------|------|------------|-----------|---------|-------------|
| VM Name | `--vm-name` | `-VMName` | ✅ | - | Nombre de la VM a eliminar |

## 🚀 Ejemplos de Uso Rápido

### Escenario 1: Crear VM básica (sin disco adicional)

**Windows:**
```powershell
.\create_vm.ps1 -BaseVM "mariadb-template" -VMName "test-db" -DBName "testdb"
```

**Linux/WSL:**
```bash
bash create_vm.sh --base-vm mariadb-template --vm-name test-db --db-name testdb
```

### Escenario 2: Crear múltiples VMs con IPs diferentes

**Windows:**
```powershell
.\create_vm.ps1 -BaseVM "mariadb-template" -VMName "db-prod" -DBName "production" -VMIP "192.168.56.110"
.\create_vm.ps1 -BaseVM "mariadb-template" -VMName "db-dev" -DBName "development" -VMIP "192.168.56.111"
```

**Linux/WSL:**
```bash
bash create_vm.sh --base-vm mariadb-template --vm-name db-prod --db-name production --vm-ip 192.168.56.110
bash create_vm.sh --base-vm mariadb-template --vm-name db-dev --db-name development --vm-ip 192.168.56.111
```

## 🔍 Solución de Problemas

### Windows

#### Error: "No se puede ejecutar scripts en este sistema"
Ejecuta en PowerShell como Administrador:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Error: "plink.exe no reconocido"
1. Descarga PuTTY desde https://www.putty.org/
2. Instala o extrae plink.exe
3. Agrega la carpeta al PATH o copia plink.exe a `C:\Windows\System32`

#### Alternativa: Usar OpenSSH de Windows
Si tienes OpenSSH instalado en Windows, puedes modificar la línea de plink por:
```powershell
ssh -o StrictHostKeyChecking=no $VMUser@$VMIP "comandos"
```

### Linux/WSL

#### Error: ": not found" o caracteres extraños
Los archivos tienen line endings de Windows (CRLF). Ejecuta:
```bash
dos2unix create_vm.sh configure_db.sh delete_vm.sh
# o
sed -i 's/\r$//' *.sh
```

#### Error: "Permission denied"
Dale permisos de ejecución:
```bash
chmod +x create_vm.sh configure_db.sh delete_vm.sh
```

#### Ejecutar desde WSL referenciando archivos de Windows
```bash
wsl bash /mnt/c/Users/TU_USUARIO/IdeaProjects/cloud/dbaas-mariadb-go/scripts/create_vm.sh --help
```

## 📝 Notas

- Los scripts **PowerShell** y **Bash** son funcionalmente equivalentes
- Usa la versión que mejor se adapte a tu entorno de trabajo
- En WSL/Ubuntu puedes usar los scripts bash nativamente
- Los scripts PowerShell incluyen validación de parámetros y mensajes de error más detallados
- Los comandos de VirtualBox (`VBoxManage`) son idénticos en ambos sistemas operativos

## 🤝 Integración con Go

Estos scripts pueden ser llamados desde la aplicación Go usando:

**Windows:**
```go
cmd := exec.Command("powershell", "-File", "scripts/create_vm.ps1", 
    "-BaseVM", "template", "-VMName", "newvm", "-DBName", "mydb")
```

**Linux/Mac:**
```go
cmd := exec.Command("bash", "scripts/create_vm.sh", 
    "--base-vm", "template", "--vm-name", "newvm", "--db-name", "mydb")
```
