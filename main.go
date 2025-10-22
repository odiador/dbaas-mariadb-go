package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/odiador/dbaas-mariadb-go/internal/db"
	"github.com/odiador/dbaas-mariadb-go/internal/ssh"
	"github.com/odiador/dbaas-mariadb-go/internal/vm"
)

type CommandRequest struct {
	Action string `json:"action"` // "create", "delete", "view"
	VMName string `json:"vm_name,omitempty"`
	DBName string `json:"db_name,omitempty"`
}

type Response struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

var logger *log.Logger

func init() {
	file, err := os.OpenFile("logs/activity.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		log.Fatal("Failed to open log file:", err)
	}
	logger = log.New(file, "", log.LstdFlags)
}

func logAction(action, details string) {
	entry := map[string]string{
		"action":  action,
		"details": details,
	}
	data, _ := json.Marshal(entry)
	logger.Println(string(data))
}

func handleCommand(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Only POST allowed", http.StatusMethodNotAllowed)
		return
	}

	var req CommandRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	resp := Response{Success: true}

	switch req.Action {
	case "create":
		if req.VMName == "" {
			resp.Success = false
			resp.Message = "VM name required"
		} else {
			err := vm.CreateVM(req.VMName)
			if err != nil {
				resp.Success = false
				resp.Message = err.Error()
			} else {
				// Configure MariaDB
				err = configureMariaDB(req.VMName, req.DBName)
				if err != nil {
					resp.Success = false
					resp.Message = err.Error()
				} else {
					resp.Message = fmt.Sprintf("VM %s created and MariaDB configured", req.VMName)
					logAction("create", fmt.Sprintf("VM: %s, DB: %s", req.VMName, req.DBName))
				}
			}
		}
	case "delete":
		if req.VMName == "" {
			resp.Success = false
			resp.Message = "VM name required"
		} else {
			err := vm.DeleteVM(req.VMName)
			if err != nil {
				resp.Success = false
				resp.Message = err.Error()
			} else {
				resp.Message = fmt.Sprintf("VM %s deleted", req.VMName)
				logAction("delete", fmt.Sprintf("VM: %s", req.VMName))
			}
		}
	case "view":
		vms, err := vm.ListVMs()
		if err != nil {
			resp.Success = false
			resp.Message = err.Error()
		} else {
			resp.Message = "VMs listed"
			resp.Data = vms
			logAction("view", "Listed VMs")
		}
	default:
		resp.Success = false
		resp.Message = "Unknown action"
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func configureMariaDB(vmName, dbName string) error {
	// Assume VM is running and SSH accessible
	client, err := ssh.NewClient(vmName, "user", "password") // TODO: proper auth
	if err != nil {
		return err
	}
	defer client.Close()

	// Install MariaDB if not installed
	_, err = client.RunCommand("sudo apt update && sudo apt install -y mariadb-server")
	if err != nil {
		return err
	}

	// Start MariaDB
	_, err = client.RunCommand("sudo systemctl start mariadb")
	if err != nil {
		return err
	}

	// Create database if dbName provided
	if dbName != "" {
		err = db.CreateDatabase(client, dbName)
		if err != nil {
			return err
		}
	}

	return nil
}

func main() {
	http.HandleFunc("/command", handleCommand)
	fmt.Println("Server starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}