package vm

import (
	"fmt"
	"os/exec"
	"strings"
)

func CreateVM(name string) error {
	// Create VM
	cmd := exec.Command("VBoxManage", "createvm", "--name", name, "--ostype", "Ubuntu_64", "--register")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create VM: %v", err)
	}

	// Configure VM (add storage, network, etc.)
	// For simplicity, assume a basic setup
	cmd = exec.Command("VBoxManage", "modifyvm", name, "--memory", "1024", "--cpus", "1")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to modify VM: %v", err)
	}

	// Create HDD
	cmd = exec.Command("VBoxManage", "createhd", "--filename", name+".vdi", "--size", "10000")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create HDD: %v", err)
	}

	// Attach HDD
	cmd = exec.Command("VBoxManage", "storagectl", name, "--name", "SATA", "--add", "sata")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to add storage controller: %v", err)
	}

	cmd = exec.Command("VBoxManage", "storageattach", name, "--storagectl", "SATA", "--port", "0", "--device", "0", "--type", "hdd", "--medium", name+".vdi")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to attach HDD: %v", err)
	}

	// Start VM (but for demo, perhaps not, as it needs ISO)
	// cmd = exec.Command("VBoxManage", "startvm", name, "--type", "headless")

	return nil
}

func DeleteVM(name string) error {
	// Power off if running
	cmd := exec.Command("VBoxManage", "controlvm", name, "poweroff")
	cmd.Run() // Ignore error if not running

	// Unregister VM
	cmd = exec.Command("VBoxManage", "unregistervm", name, "--delete")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to delete VM: %v", err)
	}

	return nil
}

func ListVMs() ([]string, error) {
	cmd := exec.Command("VBoxManage", "list", "vms")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to list VMs: %v", err)
	}

	lines := strings.Split(string(output), "\n")
	var vms []string
	for _, line := range lines {
		if strings.TrimSpace(line) != "" {
			// Parse VM name
			parts := strings.Split(line, "\"")
			if len(parts) > 1 {
				vms = append(vms, parts[1])
			}
		}
	}

	return vms, nil
}