package vm

import (
	"fmt"
	"os/exec"
	"strings"
)

func CreateVM(name, diskPath string) error {
	// Create VM
	cmd := exec.Command("VBoxManage", "createvm", "--name", name, "--ostype", "Ubuntu_64", "--register")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create VM: %v", err)
	}

	// Configure VM
	cmd = exec.Command("VBoxManage", "modifyvm", name, "--memory", "1024", "--cpus", "1")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to modify VM: %v", err)
	}

	// Add storage controller
	cmd = exec.Command("VBoxManage", "storagectl", name, "--name", "SATA", "--add", "sata")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to add storage controller: %v", err)
	}

	// Attach existing multiattach disk
	cmd = exec.Command("VBoxManage", "storageattach", name, "--storagectl", "SATA", "--port", "0", "--device", "0", "--type", "hdd", "--medium", diskPath, "--mtype", "multiattach")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to attach HDD: %v", err)
	}

	// Start VM
	cmd = exec.Command("VBoxManage", "startvm", name, "--type", "headless")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to start VM: %v", err)
	}

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