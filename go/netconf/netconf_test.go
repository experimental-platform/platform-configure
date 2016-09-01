package main

import (
	"github.com/experimental-platform/platform-utils/netutil"
	"os"
	"strings"
	"testing"
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
	if strings.Contains(result, "enoyoudontseeme0") {
		t.Errorf("Device with TxQLen 1 doesn't get filtered out properly: '%v'.", result)
	}
	if strings.Contains(result, "wl_my_home_network") {
		t.Errorf("Wireless device doesn't get filtered out properly: '%v'.", result)
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
