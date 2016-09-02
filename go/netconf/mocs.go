package main

import "github.com/experimental-platform/platform-utils/netutil"

type mocNL struct {
	macAddressData        string
	macAddressError       error
	listOfRoutesData      []string
	listOfRoutesError     error
	listOfAddressesData   []string
	listOfAddressesError  error
	listOfInterfacesData  []string
	listOfInterfacesError error
}

func (n mocNL) GetMacAddress(string) (string, error) {
	return n.macAddressData, n.macAddressError
}

func (n mocNL) GetListOfRoutes(string) ([]string, error) {
	return n.listOfRoutesData, n.listOfRoutesError
}

func (n mocNL) GetListOfAddresses(string) ([]string, error) {
	return n.listOfAddressesData, n.listOfAddressesError
}

func (n mocNL) GetListOfInterfaces() ([]string, error) {
	return n.listOfInterfacesData, n.listOfInterfacesError
}

// make sure the moc satisfies the interface
var _ NetLink = (*mocNL)(nil)

type mocNU struct {
	stats    netutil.InterfaceData
	statsErr error
}

func (n mocNU) GetInterfaceStats(name string) (netutil.InterfaceData, error) {
	return n.stats, n.statsErr
}

// make sure realNU satisfies the NetUtil interface
var _ NetUtil = (*mocNU)(nil)
