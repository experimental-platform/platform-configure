// +build linux amd64

package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"strings"

	"github.com/coreos/go-systemd/dbus"
	"github.com/experimental-platform/platform-utils/netutil"
	"github.com/vishvananda/netlink"
)

// TODO: important: This can only be tested on linux!

type realNL struct {
}

func (n realNL) GetMacAddress(name string) (string, error) {
	link, err := netlink.LinkByName(name)
	if err != nil {
		return "", err
	}
	// add hardware address
	linkAttrs := link.Attrs()
	return linkAttrs.HardwareAddr.String(), err
}

func (n realNL) GetListOfRoutes(name string) ([]string, error) {
	var result []string
	link, err := netlink.LinkByName(name)
	if err != nil {
		return result, err
	}
	routeList, err := netlink.RouteList(link, netlink.FAMILY_V4)
	if err != nil && len(routeList) < 1 {
		return result, err
	}
	for _, route := range routeList {
		if route.Gw != nil {
			result = append(result, route.Gw.String())
		}
	}
	return result, nil
}

func (n realNL) GetListOfAddresses(name string) ([]string, error) {
	var result []string
	link, err := netlink.LinkByName(name)
	if err != nil {
		return result, err
	}
	addrList, err := netlink.AddrList(link, netlink.FAMILY_ALL)
	if err != nil {
		return result, err
	}
	for _, addr := range addrList {
		result = append(result, fmt.Sprintf("%s", addr.IPNet))
	}
	return result, nil
}

func (n realNL) GetListOfInterfaces() ([]string, error) {
	result := []string{}
	linkList, err := netlink.LinkList()
	if err != nil {
		return result, err
	}
	for _, entry := range linkList {
		attrs := entry.Attrs()
		// all hardware interfaces (NOT their aliases) have a TxQLen > 1
		if attrs.TxQLen > 1 && !strings.HasPrefix(attrs.Name, "wl") {
			result = append(result, attrs.Name)
		}
	}
	return result, err
}

// make sure realNL satisfies the NetLink interface
var _ netLink = (*realNL)(nil)
var nl netLink = realNL{}

type realNU struct {
}

func (n realNU) GetInterfaceStats(name string) (netutil.InterfaceData, error) {
	return netutil.GetInterfaceStats(name)
}

// make sure realNU satisfies the NetUtil interface
var _ netUtil = (*realNU)(nil)
var nu netUtil = realNU{}

type realDBUS struct {
}

func (rec realDBUS) restartNetworkD() error {
	var connection, err = dbus.New()
	if err != nil {
		return err
	}
	result_channel := make(chan string, 1)
	var result string
	_, err = connection.RestartUnit("systemd-networkd.service", "fail", result_channel)
	if err == nil {
		result = <-result_channel
	} else {
		// Systemd Unit ERROR
		return err
	}
	if result != "done" {
		return fmt.Errorf("Unexpected SYSTEMD API result: %s", result)
	}
	return nil
}

// make sure realDBUS satisfies the DBUSUtil interface
var _ dbusUtil = (*realDBUS)(nil)
var db dbusUtil = realDBUS{}

type realFS struct {
}

func (rec realFS) WriteFile(name string, data []byte, perm os.FileMode) error {
	return ioutil.WriteFile(name, data, perm)
}

func (rec realFS) Remove(name string) error {
	return os.Remove(name)
}

func (rec realFS) Stat(name string) (os.FileInfo, error) {
	return os.Stat(name)
}

// make sure realFS satisfies the FSUtil interface
var _ fsUtil = (*realFS)(nil)
var fs fsUtil = realFS{}
