package main

import (
	"errors"
	"fmt"
	"strconv"
	"strings"
)

type appManifest struct {
	ShortName        string            `json:"short_name"`
	FullName         string            `json:"full_name"`
	RequiredServices []string          `json:"required_services"`
	DockerImageName  string            `json:"docker_image_name"`
	DockerImageTag   string            `json:"docker_image_tag"`
	DataVolumes      map[string]string `json:"data_volumes"`
	Env              map[string]string `json:"env"`
	PortMappings     map[string]string `json:"port_mappings"` // key = host port, value = container port
}

func stringContainsOnly(s, charset string) bool {
	for _, char := range s {
		if !strings.ContainsRune(charset, char) {
			return false
		}
	}

	return true
}

func (a *appManifest) RequiresService(service string) bool {
	for _, s := range a.RequiredServices {
		if s == service {
			return true
		}
	}
	return false
}

func isValidPort(s string) (bool, int) {
	i, err := strconv.Atoi(s)
	if err != nil {
		return false, 0
	}

	if i < 1 || i > 65535 {
		return false, i
	}

	return true, i
}

func (a *appManifest) Verify() error {
	// a.ShortName
	if len(a.ShortName) == 0 {
		return errors.New("App's short name cannot be empty")
	}
	if !stringContainsOnly(a.ShortName, "abcdefghijklmnopqrstuvwxyz0123456789_") {
		return errors.New("App's short name can only contain lowercase letters, numbers and undescores")
	}

	// a.FullName
	if len(a.FullName) == 0 {
		return errors.New("App's full name cannot be empty")
	}
	if !stringContainsOnly(strings.ToLower(a.FullName), "abcdefghijklmnopqrstuvwxyz0123456789 _") {
		return errors.New("App's full name can only contain letters, numbers, whitespaces and undescores")
	}

	// TODO make sure DockerImageName is valid
	// TODO make sure DockerImageTag is valid

	for k, v := range a.DataVolumes {
		if len(k) == 0 {
			return errors.New("App's data volume name cannot be empty")
		}
		if !stringContainsOnly(k, "abcdefghijklmnopqrstuvwxyz0123456789") {
			return errors.New("App's data volume names can only contain lowercase letters and numbers")
		}

		if len(v) == 0 {
			return errors.New("App's data volume path cannot be empty")
		}
		if !stringContainsOnly(strings.ToLower(v), "abcdefghijklmnopqrstuvwxyz0123456789_-/") {
			return errors.New("App's data volume paths can only contain letters, numbers, undescores, dashes and forward-slashes")
		}
		if v[0] != '/' {
			return errors.New("App's data volume path must be an absolute path")
		}
	}

	// TODO make sure Env is hardcore safe

	restrictedPorts := []int{22}
	for k, v := range a.PortMappings {
		ok, i := isValidPort(k)
		if !ok {
			return errors.New("Port mapping values must be 16-bit unsigned ints")
		}

		for _, rp := range restrictedPorts {
			if i == rp {
				return fmt.Errorf("Port %d is restricted and cannot be mapped to", rp)
			}
		}

		ok, _ = isValidPort(v)
		if !ok {
			return errors.New("Port mapping values must be 16-bit unsigned ints")
		}
	}

	return nil
}
