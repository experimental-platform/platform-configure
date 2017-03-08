package main

import (
	"bytes"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"path"
	"strconv"
	"strings"
	"text/template"

	"github.com/experimental-platform/platform-utils/netutil"
)

const reportTemplate = `
Interface: {{ .Interface }}
=====================
Mode:      {{ .Mode }}
State:     {{ .State }}
Associated Addresses:
{{ range $key, $value := .Addresses }}    * {{ $value }}
{{ else }}    -- NONE --
{{ end }}HWAddress:   {{ .HWAddress }}
Gateway:   {{ .Gateway }}
Nameserver:
{{ range $key, $value := .Nameserver }}    * {{ $value }}
{{ end }}Domains:
{{ range $key, $value := .Domains }}    * {{ $value }}
{{ end }}`

type reportTemplateData struct {
	Interface  string
	State      string
	Mode       string
	Addresses  []string
	HWAddress  string
	Gateway    string
	Domains    []string
	Nameserver []string
}

type netLink interface {
	GetMacAddress(string) (string, error)
	GetListOfRoutes(string) ([]string, error)
	GetListOfAddresses(string) ([]string, error)
	GetListOfInterfaces() ([]string, error)
}

type netUtil interface {
	GetInterfaceStats(string) (netutil.InterfaceData, error)
}

type dbusUtil interface {
	restartNetworkD() error
}

type fsUtil interface {
	WriteFile(string, []byte, os.FileMode) error
	Remove(string) error
	Stat(name string) (os.FileInfo, error)
}

func getNetInterfaceData(name string) (*reportTemplateData, error) {
	result := new(reportTemplateData)
	result.Interface = name
	interfaceData, err := nu.GetInterfaceStats(result.Interface)
	if err != nil {
		return result, err
	}
	if interfaceData.NETWORK_FILE == "/usr/lib64/systemd/network/zz-default.network" {
		result.Mode = "DHCP"
	} else {
		result.Mode = "STATIC"
	}
	result.Nameserver = interfaceData.DNS
	result.Domains = interfaceData.DOMAINS
	result.State = interfaceData.OPER_STATE
	// add hardware address
	result.HWAddress, err = nl.GetMacAddress(result.Interface)
	if err != nil {
		return result, err
	}
	// add ip addresses and netmasks
	result.Addresses, err = nl.GetListOfAddresses(result.Interface)
	if err != nil {
		return result, err
	}
	routes, err := nl.GetListOfRoutes(result.Interface)
	if err != nil {
		return result, err
	}
	if len(routes) >= 1 {
		result.Gateway = routes[0]
	}
	return result, nil
}

func reportOnInterface(name string) (string, error) {
	result, err := getNetInterfaceData(name)
	if err != nil {
		return "", fmt.Errorf("getNetInterfaceData(): %s", err.Error())
	}
	// Create the report
	report, err := template.New("Report").Parse(reportTemplate)
	if err != nil {
		return "", err
	}
	buff := bytes.NewBufferString("")
	err = report.Execute(buff, result)
	if err != nil {
		return "", err
	}
	return buff.String(), nil
}

func showConfig() (string, error) {
	// TODO: test this!
	var err error
	var result string
	interfaceNames, err := nl.GetListOfInterfaces()
	if err != nil {
		return result, err
	}
	for _, name := range interfaceNames {
		report, err := reportOnInterface(name)
		if err != nil {
			return "", err
		}
		result += report
	}
	return result, err
}

func enableDHCP(name string) (string, error) {
	// TODO: Test this!
	result := fmt.Sprintf("Getting interface stats for '%s'...", name)
	iData, err := nu.GetInterfaceStats(name)
	if err != nil {
		return result, fmt.Errorf("\nERROR: Interface '%s' not found", name)
	}
	result += "OKAY\n"
	if iData.NETWORK_FILE == "/usr/lib64/systemd/network/zz-default.network" {
		result += "SUCCESS: Already using DHCP\n"
		return result, nil
	}
	// in most cases we'll just remove any user provided config, so the systems default takes hold
	if strings.Contains(iData.NETWORK_FILE, "/etc/systemd/network/") {
		result += fmt.Sprintf("Custon Config detected: '%s'\n", iData.NETWORK_FILE)
		if _, err := os.Stat(iData.NETWORK_FILE); err == nil {
			// It's okay if the file does not exists, as this frequently happens
			// when configuring stuff manually or when not rebooting.
			err = fs.Remove(iData.NETWORK_FILE)
			if err != nil {
				return result, fmt.Errorf("ERROR removing '%s'\n", iData.NETWORK_FILE)
			}

		}
		result += fmt.Sprintf("Successfully removed '%s'\n", iData.NETWORK_FILE)
		err = db.restartNetworkD()
		if err != nil {
			result += "SUCCESS, PLEASE REBOOT!\n"
		}
		result += "SUCCESS, using DHCP.\nPLEASE REBOOT NOW ('sudo reboot')!\n"
		return result, nil
	}
	return result, fmt.Errorf("Sorry, no idea how to handle '%s'.", iData.NETWORK_FILE)
}

type staticData struct {
	Mac     string
	Address string
	Gateway string
	DNS     []string
}

const unitTemplate = `[Match]
MACAddress={{ .Mac }}

[Network]
Address={{ .Address }}
Gateway={{ .Gateway }}
{{ range $key, $value := .DNS }}DNS={{ $value }}
{{ end }}`

func parseMap(s string) (*net.IPMask, error) {
	r := make(net.IPMask, net.IPv4len)
	o := strings.Split(s, ".")
	if len(o) != 4 {
		return &r, fmt.Errorf("Not a valid net mask: %s", s)
	}
	for i, s := range o {
		b, err := strconv.Atoi(s)
		if err != nil {
			return &r, err
		}
		r[i] = byte(b)
	}
	return &r, nil
}

func setStaticConfig(iface, address, netmask, gateway, dns string) (string, error) {
	// TODO: test this!
	iData, err := nu.GetInterfaceStats(iface)
	result := fmt.Sprintf("Configuring interface '%v'...\n", iface)
	if err != nil {
		return result, fmt.Errorf("\nERROR: Interface '%s' not found", iface)
	}
	templateData := new(staticData)
	templateData.Mac, err = nl.GetMacAddress(iface)
	if err != nil {
		return "", err
	}

	// create IP/MASK entry
	mask, err := parseMap(netmask)
	if err != nil {
		return "", err
	}
	ipAddress := net.ParseIP(address)
	if ipAddress == nil {
		return "", fmt.Errorf("'%s' (address) is not a valid IP address", address)
	}
	ipNet := net.IPNet{IP: ipAddress, Mask: *mask}
	templateData.Address = ipNet.String()
	gatewayIP := net.ParseIP(gateway)
	if !ipNet.Contains(gatewayIP) {
		return "", fmt.Errorf("🖕\tGateway address '%s' is not within the network '%s'", gatewayIP, ipNet.String())
	}
	if gatewayIP == nil {
		return "", fmt.Errorf("'%s' (gateway) is not a valid IP address", gateway)
	}
	templateData.Gateway = gatewayIP.String()
	// parse dns
	var dnsList []string
	for _, s := range strings.Split(strings.Trim(dns, " "), ",") {
		ip := net.ParseIP(strings.Trim(s, " "))
		if ip == nil {
			return "", fmt.Errorf("'%s' (dns) is not a valid IP address", s)
		}
		dnsList = append(dnsList, ip.String())
	}
	templateData.DNS = dnsList

	unitData, err := template.New("Unit").Parse(unitTemplate)
	if err != nil {
		return "", err
	}
	buff := bytes.NewBufferString("")
	err = unitData.Execute(buff, templateData)
	if err != nil {
		return "", err
	}

	if iData.NETWORK_FILE != "/usr/lib64/systemd/network/zz-default.network" {
		if strings.Contains(iData.NETWORK_FILE, "/etc/systemd/network/") {
			err = fs.Remove(iData.NETWORK_FILE)
			if err != nil {
				return "", err
			}
		} else {
			return "", fmt.Errorf("No idea what to do with '%s', sorry", iData.NETWORK_FILE)
		}
	}
	err = fs.WriteFile(path.Join("/etc/systemd/network/", iface+".network"), buff.Bytes(), 0644)
	if err != nil {
		return "", err
	}
	err = db.restartNetworkD()
	if err != nil {
		result += "SUCCESS, PLEASE REBOOT NOW (with 'sudo reboot')!\n"
	}
	result += "SUCCESS, using static configuration now!\n" +
		"PLEASE REBOOT NOW WITH 'sudo reboot'.\n"
	return result, err
}

func resetToDHCP() (string, error) {
	interfaceNames, err := nl.GetListOfInterfaces()
	var result string
	if err != nil {
		return "", err
	}
	for _, name := range interfaceNames {
		result += fmt.Sprintf("Resetting interface '%s':\n", name)
		message, err := enableDHCP(name)
		result += fmt.Sprintf("%s\n\n", message)
		if err != nil {
			return result, err
		}
	}
	result += "\nSUCCESS.\n\nPLEASE REBOOT NOW ('sudo reboot')!\n"
	return result, err
}

func switchByCommandline() (string, error) {
	var CommandLine = flag.NewFlagSet(os.Args[0], flag.ExitOnError)
	CommandLine.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s:\n", os.Args[0])
		CommandLine.PrintDefaults()
	}
	show := CommandLine.Bool("show", false, "Show configuration and available interfaces")
	resetAll := CommandLine.Bool("reset", false, "(Re)set all interfaces to DHCP")
	mode := CommandLine.String("mode", "", "'dhcp' or 'static'")
	networkInterface := CommandLine.String("interface", "", "Interface name to be configured")
	address := CommandLine.String("address", "", "IP address to be set for the interface")
	netmask := CommandLine.String("netmask", "", "Set the netmask")
	gateway := CommandLine.String("gateway", "", "Gateway address")
	dns := CommandLine.String("dns", "", "IP addresses of DNS servers, separated by comma")
	version := CommandLine.Bool("version", false, "Show the version of this tool.")
	err := CommandLine.Parse(os.Args[1:])
	if err != nil {
		log.Fatalf("ERROR: %v", err)
	}
	switch {
	case *show:
		return showConfig()
	case *version:
		return "Version: 0.9 (missing menu and repair)", nil
	case *resetAll:
		return resetToDHCP()
	case *mode == "dhcp":
		return enableDHCP(*networkInterface)
	case *mode == "static":
		return setStaticConfig(*networkInterface, *address, *netmask, *gateway, *dns)
	default:
		// TODO: implement menu interface
		CommandLine.Usage()
		return "", errors.New("Invalid flag.")
	}
}

func main() {
	message, err := switchByCommandline()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(message)
	os.Exit(0)
}
