package main

import (
	"crypto/rand"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"os"
	"os/exec"
	"regexp"
	"strings"

	"github.com/kdomanski/tenus"
)

const constInterfaceName string = "engitlab0"

func getDefaultInterface() (string, error) {
	cmd := exec.Command("ip", "route", "get", "8.8.8.8")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", err
	}

	reg, err := regexp.Compile("dev e[nt]+[0-9a-z_]+")
	if err != nil {
		return "", err
	}

	found := reg.Find(out)
	if found == nil {
		return "", fmt.Errorf("getDefaultInterface(): error parsing the output of `ip`")
	}

	split := strings.Split(string(found), " ")
	if len(split) != 2 {
		return "", fmt.Errorf("getDefaultInterface(): error parsing the output of `ip`")
	}

	return split[1], nil
}

func createMac() string {
	r := make([]byte, 3)
	_, err := rand.Read(r)
	if err != nil {
		panic(fmt.Sprintf("createMac(): Failed to generate random MAC bytes: %s", err.Error()))
	}

	return fmt.Sprintf("00:11:22:%x:%x:%x", r[0:1], r[1:2], r[2:3])
}

func getMac() string {
	// if the MAC file doesn't exist
	if _, err := os.Stat("/etc/protonet/gitlab/mac"); os.IsNotExist(err) {

		// create the parent folder, if they are missing
		if os.Stat("/etc/protonet"); os.IsNotExist(err) {
			err = os.Mkdir("/etc/protonet/gitlab", 0755)
			if err != nil {
				panic(err)
			}
		}

		if os.Stat("/etc/protonet/gitlab"); os.IsNotExist(err) {
			err := os.Mkdir("/etc/protonet/gitlab", 0755)
			if err != nil {
				panic(err)
			}
		}

		newMac := createMac()

		err := ioutil.WriteFile("/etc/protonet/gitlab/mac", []byte(newMac), 0644)
		if err != nil {
			panic(err)
		}
		return string(newMac)
	}

	data, err := ioutil.ReadFile("/etc/protonet/gitlab/mac")
	if err != nil {
		panic(err)
	}
	return string(data)
}

func createInterface(ifName string) error {
	_, err := net.InterfaceByName(ifName)
	if err == nil {
		log.Printf("Interface '%s' already exists.", ifName)
		return nil
	}

	mac := getMac()

	defaultInterface, err := getDefaultInterface()
	if err != nil {
		return err
	}

	link, err := tenus.NewMacVlanLinkWithOptions(defaultInterface, tenus.MacVlanOptions{Dev: ifName, MacAddr: mac})
	if err != nil {
		return err
	}

	err = link.SetLinkUp()
	if err != nil {
		return err
	}

	return nil
}

func getInterfaceIP(ifName string) (string, error) {
	interf, err := net.InterfaceByName(ifName)
	if err != nil {
		return "", err
	}

	addrs, err := interf.Addrs()
	if err != nil {
		return "", err
	}

	// TODO: what about len(addr) > 1 ?
	if len(addrs) == 0 {
		return "", fmt.Errorf("the device %s has no network addresses", ifName)
	}

	cidr := addrs[0].String()
	ip, _, err := net.ParseCIDR(cidr)
	if err != nil {
		return "", fmt.Errorf("error parsing CIDR '%s'", cidr)
	}

	return ip.String(), nil
}

func printUsage() {
	fmt.Printf("Usage: %s start|stop|show\n", os.Args[0])
	fmt.Printf("\tstart:\tcreate the gitlab interface if it does not yet exist.\n")
	fmt.Printf("\tstop:\tdestroy the gitlab interface if it does exist.\n")
	fmt.Printf("\tshow:\tshow the ipv4 address if the interface has one.\n")
}

func main() {
	if len(os.Args) != 2 {
		printUsage()
		os.Exit(1)
	}

	switch os.Args[1] {
	case "start":
		err := createInterface(constInterfaceName)
		if err != nil {
			log.Fatalf("failed to create interface: %s\n", err.Error())
		}
		break
	case "stop":
		err := tenus.DeleteLink(constInterfaceName)
		if err != nil {
			log.Fatalf("failed to delete interface: %s\n", err.Error())
		}
		break
	case "show":
		ip, err := getInterfaceIP(constInterfaceName)
		if err != nil {
			log.Fatalf("failed to get interface IP: %s\n", err.Error())
		}

		fmt.Print(ip)
		break
	default:
		printUsage()
		os.Exit(1)
	}
}
