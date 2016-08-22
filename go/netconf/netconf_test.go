package main

import (
	"testing"
	"os"
	"github.com/experimental-platform/platform-utils/netutil"
	"github.com/vishvananda/netlink"
	"strings"
	"net"
)

type mocNL struct {
	link          netlink.Link
	linkErr       error
	routeList     []netlink.Route
	routeError    error
	addrList      []netlink.Addr
	addrError     error
	linkList      []netlink.Link
	linkListError error
}

func (n mocNL) LinkByName(s string) (netlink.Link, error) {
	return n.link, n.linkErr
}

func (n mocNL) RouteList(l netlink.Link, f int) ([]netlink.Route, error) {
	return n.routeList, n.routeError
}

func (n mocNL) AddrList(l netlink.Link, f int) ([]netlink.Addr, error) {
	return n.addrList, n.addrError
}

func (n mocNL) LinkList() ([]netlink.Link, error) {
	return n.linkList, n.linkListError
}

// make sure the moc satisfies the interface
var _ NetLink = (*mocNL)(nil)

type mocNU struct {
	iface    string
	ifaceErr error
	stats    netutil.InterfaceData
	statsErr error
}

func (n mocNU) GetDefaultInterface() (string, error) {
	return n.iface, n.ifaceErr
}

func (n mocNU) GetInterfaceStats(name string) (netutil.InterfaceData, error) {
	return n.stats, n.statsErr
}

// make sure realNU satisfies the NetUtil interface
var _ NetUtil = (*mocNU)(nil)

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
	nuMoc := mocNU{
		stats: netutil.InterfaceData{
			ADMIN_STATE:"configured",
			OPER_STATE:"routable",
			NETWORK_FILE:"/usr/lib64/systemd/network/zz-default.network",
			DNS:[]string{"8.8.8.8", "10.11.0.2", "62.220.18.8"},
			NTP:"",
			DOMAINS:[]string{"office.protorz.net"},
			WILDCARD_DOMAIN:false, LLMNR:true,
			DHCP_LEASE:"/run/systemd/netif/leases/4",
		},
		statsErr: nil,
		iface: "fabooo",
		ifaceErr: nil,
	}
	nlMoc := mocNL{
		addrList: []netlink.Addr{{
			IPNet: func() *net.IPNet {
				_, net, _ := net.ParseCIDR("172.16.0.123/16")
				return net
			}(),
			Label:"eno1", Flags:0, Scope:0},
		},
		addrError: nil,
		link: &netlink.Device{
			LinkAttrs:netlink.LinkAttrs{
				Index:4, MTU:1500, TxQLen:1000, Name:"eno1",
				HardwareAddr: net.HardwareAddr{0x54, 0xbe, 0xf7, 0x66, 0x2c, 0x49},
				Flags: 0x13, ParentIndex: 0, MasterIndex: 0,
				Namespace:interface{}(nil),
				Alias:"",
				Promisc:0},
		},
		linkErr: nil,
		routeList: []netlink.Route{
			{
				Dst: nil,
				Src: net.ParseIP("172.16.10.239"),
				Gw: net.ParseIP("172.16.0.1"),
				Table: 254,
				ILinkIndex: 4,
			},
			{
				ILinkIndex: 4,
				Dst: func() *net.IPNet {
					_, net, _ := net.ParseCIDR("172.16.0.0/16")
					return net
				}(),
				Src: net.ParseIP("172.16.10.239"),
				Gw: nil,
				Table: 254,
			},
		},
		routeError: nil,
	}
	result, err := switchByCommandline(nuMoc, nlMoc)
	if err != nil {
		t.Errorf("Static mode failure: %v", err)
	}
	t.Log("RESULT: \n" + result)
	if ! strings.Contains("gagaga", result) {
		t.Errorf("Expected 'gagaga', got '%v'.", result)
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