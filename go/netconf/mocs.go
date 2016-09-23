package main

import (
	"os"

	"github.com/experimental-platform/platform-utils/netutil"
)

type mocNL struct {
	macAddressData        map[string]string
	macAddressError       error
	listOfRoutesData      []string
	listOfRoutesError     error
	listOfAddressesData   []string
	listOfAddressesError  error
	listOfInterfacesData  []string
	listOfInterfacesError error
}

func (n mocNL) GetMacAddress(name string) (string, error) {
	return n.macAddressData[name], n.macAddressError
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
var _ netLink = (*mocNL)(nil)

type mocNU struct {
	stats    netutil.InterfaceData
	statsErr error
}

func (n mocNU) GetInterfaceStats(name string) (netutil.InterfaceData, error) {
	return n.stats, n.statsErr
}

// make sure realNU satisfies the NetUtil interface
var _ netUtil = (*mocNU)(nil)

type mocDBUS struct {
	err error
}

func (rec mocDBUS) restartNetworkD() error {
	return rec.err
}

// make sure mocDBUS satisfies the DBUSUtil interface
var _ dbusUtil = (*mocDBUS)(nil)

type mocFS struct {
	err       error
	statData  os.FileInfo
	callNames []string
	callData  [][]byte
}

func (rec *mocFS) WriteFile(name string, data []byte, perm os.FileMode) error {
	rec.callNames = append(rec.callNames, name)
	rec.callData = append(rec.callData, data)
	return rec.err
}

func (rec *mocFS) Remove(name string) error {
	return rec.err
}

func (rec *mocFS) Stat(name string) (os.FileInfo, error) {
	return rec.statData, rec.err
}

func newMocFS() (*mocFS, *[]string, *[][]byte) {
	var moc mocFS
	moc.callData = [][]byte{}
	moc.callNames = []string{}
	return &moc, &moc.callNames, &moc.callData
}

var _ fsUtil = (*mocFS)(nil)
