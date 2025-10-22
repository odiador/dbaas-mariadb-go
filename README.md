# dbaas-mariadb-go

Por:

- Juan Manuel Amador
- Royer García
- Santiago Londoño

## Descripción

Aplicación web mínima en Go para gestionar instancias de MariaDB usando VirtualBox VMs.

## Requisitos

- VirtualBox instalado
- VBoxManage en PATH
- Go 1.19+
- MariaDB client
- OpenSSH client

## Instalación

```bash
sudo apt install virtualbox golang mariadb-client openssh-client
```

## Configuración

1. Copia `.env.example` a `.env` y configura las variables de entorno:
   ```bash
   cp .env.example .env
   # Edita .env con tus valores
   ```

2. Construir la aplicación:
   ```bash
   go build
   ```

3. Ejecutar el servidor:
   ```bash
   ./dbaas-mariadb-go
   ```

3. Enviar comandos vía POST a `http://localhost:8080/command`

### Ejemplos de comandos

- Ver VMs:
  ```bash
  curl -X POST http://localhost:8080/command -H "Content-Type: application/json" -d '{"action": "view"}'
  ```

- Crear VM y configurar MariaDB:
  ```bash
  curl -X POST http://localhost:8080/command -H "Content-Type: application/json" -d '{"action": "create", "vm_name": "testvm", "db_name": "testdb", "disk_path": "/path/to/mariadb-template.vdi"}'
  ```

- Eliminar VM:
  ```bash
  curl -X POST http://localhost:8080/command -H "Content-Type: application/json" -d '{"action": "delete", "vm_name": "testvm"}'
  ```

## Scripts

Además de la aplicación web, se incluyen scripts para operaciones manuales:

### Crear VM
```bash
./scripts/create_vm.sh --base-vm mariadb-template --vm-name servidor-db-1 --disk-path /path/to/multiattach.vdi --db-name mi_db
```

### Eliminar VM
```bash
./scripts/delete_vm.sh --vm-name servidor-db-1
```

### Configurar DB
```bash
./scripts/configure_db.sh --vm-ip 192.168.56.102 --db-name mi_db
```

## Logs

Los logs se guardan en `logs/activity.log` en formato JSON.

## Estructura del proyecto

```
dbaas-mariadb-go/
├── main.go
├── internal/
│   ├── vm/manager.go
│   ├── ssh/sshclient.go
│   └── db/dbmanager.go
├── logs/activity.log
├── scripts/
│   ├── create_vm.sh
│   ├── delete_vm.sh
│   └── configure_db.sh
└── go.mod
```
