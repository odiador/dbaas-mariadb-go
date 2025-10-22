package ssh

import (
	"fmt"
	"os/exec"
	"strings"
)

type Client struct {
	host string
	user string
}

func NewClient(host, user, password string) (*Client, error) {
	// For simplicity, assume passwordless SSH or key auth
	// In real, might need to set up expect or something
	return &Client{host: host, user: user}, nil
}

func (c *Client) RunCommand(cmd string) (string, error) {
	fullCmd := fmt.Sprintf("ssh %s@%s '%s'", c.user, c.host, cmd)
	output, err := exec.Command("bash", "-c", fullCmd).Output()
	if err != nil {
		return "", fmt.Errorf("SSH command failed: %v", err)
	}
	return strings.TrimSpace(string(output)), nil
}

func (c *Client) Close() {
	// No-op
}