// +build linux amd64

package main

import (
	"fmt"
	"github.com/experimental-platform/platform-utils/netutil"
	"github.com/vishvananda/netlink"
	"strings"
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
var _ NetLink = (*realNL)(nil)
var nl NetLink = realNL{}

type realNU struct {
}

func (n realNU) GetInterfaceStats(name string) (netutil.InterfaceData, error) {
	return netutil.GetInterfaceStats(name)
}

// make sure realNU satisfies the NetUtil interface
var _ NetUtil = (*realNU)(nil)
var nu NetUtil = realNU{}
