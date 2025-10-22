package db

import (
	"fmt"

	"github.com/odiador/dbaas-mariadb-go/internal/ssh"
)

func CreateDatabase(client *ssh.Client, dbName, dbUser, dbPass string) error {
	// Create database
	cmd := fmt.Sprintf("sudo mysql -e 'CREATE DATABASE IF NOT EXISTS %s;'", dbName)
	_, err := client.RunCommand(cmd)
	if err != nil {
		return fmt.Errorf("failed to create database: %v", err)
	}

	// Create user and grant privileges
	cmd = fmt.Sprintf("sudo mysql -e \"CREATE USER IF NOT EXISTS '%s'@'%%' IDENTIFIED BY '%s'; GRANT ALL PRIVILEGES ON %s.* TO '%s'@'%%'; FLUSH PRIVILEGES;\"", dbUser, dbPass, dbName, dbUser)
	_, err = client.RunCommand(cmd)
	if err != nil {
		return fmt.Errorf("failed to create user: %v", err)
	}

	return nil
}