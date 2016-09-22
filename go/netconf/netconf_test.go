package main

import (
	"os"
	"strings"
	"testing"

	"github.com/experimental-platform/platform-utils/netutil"
)

/*
	Test DHCP
*/

// TODO: test dhcp with additional values (=> failure)
// TODO: test -mode dhcp with existing static setting
// TODO: test -mode dhcp with existing dhcp setting (noop)

/*
	Test static configuration
*/

func TestSetStaticSimple(t *testing.T) {
	oldArgs := os.Args
	defer func() {
		os.Args = oldArgs
	}()
	os.Args = []string{
		"foobar", "-mode", "static", "-interface", "enomeno42",
		"-address", "192.168.23.42", "-netmask", "255.255.255.128",
		"-gateway", "192.168.23.45", "-dns", "8.8.8.8, 8.8.4.4",
	}
	nu = mocNU{
		stats: netutil.InterfaceData{
			ADMIN_STATE:     "configured",
			OPER_STATE:      "routable",
			NETWORK_FILE:    "/usr/lib64/systemd/network/zz-default.network",
			DNS:             []string{"8.8.8.8", "10.11.0.2", "62.220.18.8"},
			NTP:             "",
			DOMAINS:         []string{"blablabla.lalala.net"},
			WILDCARD_DOMAIN: false, LLMNR: true,
			DHCP_LEASE: "/run/systemd/netif/leases/4",
		},
		statsErr: nil,
	}
	nl = mocNL{
		listOfAddressesData:  []string{"172.16.0.123/16"},
		listOfInterfacesData: []string{"eno0", "eno1", "enomeno42"},
		listOfRoutesData:     []string{"172.16.0.1"},
		macAddressData:       "0a:66:7f:12:8d:15",
	}
	var fsNames *[]string
	var fsData *[][]byte
	fs, fsNames, fsData = newMocFS()
	result, err := switchByCommandline()
	if err != nil {
		t.Errorf("Static mode failure: %v", err)
	}
	if !strings.Contains(result, "enomeno42") {
		t.Errorf("Expected 'enomeno42', got '%v'.", result)
	}
	// checking the file name the data gets written to
	fileNameCorrect := false
	for _, name := range *fsNames {
		if name == "/etc/systemd/network/enomeno42.network" {
			fileNameCorrect = true
		}
	}
	if !fileNameCorrect {
		t.Errorf("Error writing config file, got: '%#v'.", (*fsNames))
	}
	// checking the content of the config file
	expectedData := []string{
		"[Match]\nMACAddress=0a:66:7f:12:8d:15\n",
		"Address=192.168.23.42/25\n",
		"Gateway=192.168.23.45\n",
		"DNS=8.8.8.8\n",
		"DNS=8.8.4.4\n",
	}
	receivedData := string((*fsData)[0])
	for _, line := range expectedData {
		if !strings.Contains(receivedData, line) {
			t.Errorf("Missing line:\n%s\n\nConfig:%s\n", line, receivedData)
		}
	}
}

// TODO: test static with gateway outside netmask
// TODO: test static with invalid values for ip, gateway, netmask, dns
// TODO: test static with incomplete config
// TODO: test static with dns server list
// TODO: test -mode static
// TODO: test -address <ip>
// TODO: test -netmask <mask>
// TODO: test -gateway <gateway>
// TODO: test -dns <ip>|<ip>,<ip2>,...
// TODO: test static with initial dhcp setting
// TODO: test static with initial different static
// TODO: test static with initial identical static (noop)

/*
	Test SHOW function
*/

// TODO: test show with additional settings (=>failure)
// TODO: test show with initial dhcp settings
// TODO: test show with initial static settings
// TODO: test show with initial defect settings

func TestShowConfig(t *testing.T) {
	oldArgs := os.Args
	defer func() {
		os.Args = oldArgs
	}()
	os.Args = []string{"foobar", "-show"}
	nu = mocNU{
		stats: netutil.InterfaceData{
			ADMIN_STATE:     "configured",
			OPER_STATE:      "routable",
			NETWORK_FILE:    "/usr/lib64/systemd/network/zz-default.network",
			DNS:             []string{"8.8.8.8", "10.11.0.2", "62.220.18.8"},
			NTP:             "",
			DOMAINS:         []string{"blablabla.lalala.net"},
			WILDCARD_DOMAIN: false, LLMNR: true,
			DHCP_LEASE: "/run/systemd/netif/leases/4",
		},
		statsErr: nil,
	}
	nl = mocNL{
		listOfAddressesData:  []string{"172.16.0.123/16"},
		listOfInterfacesData: []string{"eno0", "eno1", "enototallyyourdevice1"},
		listOfRoutesData:     []string{"172.16.0.1"},
		macAddressData:       "0a:66:7f:12:8d:15",
	}
	result, err := switchByCommandline()
	if err != nil {
		t.Errorf("Static mode failure: %v", err)
	}

	if !strings.Contains(result, "enototallyyourdevice1") {
		t.Errorf("Expected 'enototallyyourdevice1', got '%v'.", result)
	}
}

/*
	Test REPAIR function
*/
// TODO: test repair with additional settings (=> failure)
// TODO: test -repair with multiple defects.

/*
	TEST MENU
*/

// TODO: make sure every menu item starts the correct functions.

/*
	TEST LINUX
*/
// TODO: make sure that on Linux the real NetLink and NetUtil are compiled in...
