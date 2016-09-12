package main

import (
	rabbit "github.com/michaelklishin/rabbit-hole"
	"flag"
	"os"
	"fmt"
	"log"
	"errors"
	"bytes"
	"text/template"
	"github.com/experimental-platform/platform-utils/dockerutil"
	skvs "github.com/experimental-platform/platform-skvs/client"
	"math/rand"
	"time"
)

// TODO: create setting (create user, create vhost, connect user and vhost)
// TODO: delete setting

func getRabbitConfig() *rabbit.Client {
	host, err := dockerutil.GetContainerIP("rabbitmq")
	if err != nil {
		// TODO: THIS IS BULLSHIT!
		host = "127.0.0.1"
	}
	// TODO: get user and password from skvs
	con, err := rabbit.NewClient(fmt.Sprintf("http://%s:15672", host), "guest", "guest")
	if err != nil {
		panic(err)
	}
	return con
}

func deleteSettings(name string) (string, error) {
	con := getRabbitConfig()
	_, err := con.DeleteVhost(name)
	if err != nil {
		fmt.Printf("ERROR DELETING VHOST: %v", err)
	}
	_, err = con.DeleteUser(name)
	if err != nil {
		fmt.Printf("ERROR DELETING USER: %v", err)
	}
	// delete url from SKVS
	key := fmt.Sprintf("app/%s/rabbitmq", name)
	err = skvs.Delete(key)
	return "DONE\n", err
}

// https://siongui.github.io/2015/04/13/go-generate-random-string/
func randomString(strlen int) string {
	rand.Seed(time.Now().UTC().UnixNano())
	const chars = "abcdefghijklmnopqrstuvwxyz0123456789_-+/"
	result := make([]byte, strlen)
	for i := 0; i < strlen; i++ {
		result[i] = chars[rand.Intn(len(chars))]
	}
	return string(result)
}

func createUser(name string) (string, error) {
	con := getRabbitConfig()
	// create password and (update or create) user
	password := randomString(20)
	userInfo := rabbit.UserSettings{
		Name: name,
		Password: password,
		Tags: "autocreated",
	}
	_, err := con.PutUser(name, userInfo)
	return password, err
}

func createVHost(name string) error {
	con := getRabbitConfig()
	vhostSetting := rabbit.VhostSettings{}
	_, err := con.PutVhost(name, vhostSetting)
	return err
}

func updatePermissions(name string) error {
	con := getRabbitConfig()
	permissions := rabbit.Permissions{
		Read:".*",
		Write:".*",
		Configure:".*",
	}
	_, err := con.UpdatePermissionsIn(name, name, permissions)
	return err
}

func createSettings(name string) (string, error) {
	password, err := createUser(name)
	if err != nil {
		panic(err)
	}
	err = createVHost(name)
	if err != nil {
		panic(err)
	}
	err = updatePermissions(name)
	if err != nil {
		panic(err)
	}
	// write user, password and vhost to SKVS
	key := fmt.Sprintf("app/%s/rabbitmq", name)
	url := fmt.Sprintf("amqp://%s:%s@rabbitmq:5672/%s", name, password, name)
	err = skvs.Set(key, url)
	return "DONE.\nNew Password was set\n", err
}

const reportTemplate = `Access Control and Permissions:

{{ range $key, $value := . }}Name:	{{ $value.User }}
	VHost:		{{ $value.Vhost }}
	Configure:	{{ $value.Configure }}
	Write:		{{ $value.Write }}
	Read:		{{ $value.Read }}
{{ end }}
`

func listSettings() (string, error) {
	con := getRabbitConfig()
	perms, err := con.ListPermissions()
	if err != nil {
		panic(err)
	}
	// Create the report
	report, err := template.New("Report").Parse(reportTemplate)
	if err != nil {
		return "", err
	}
	buff := bytes.NewBufferString("")
	err = report.Execute(buff, perms)
	if err != nil {
		return "", err
	}
	return buff.String(), nil
}

func switchByCommandLine() (string, error) {
	var CommandLine = flag.NewFlagSet(os.Args[0], flag.ExitOnError)
	CommandLine.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s:\n", os.Args[0])
		CommandLine.PrintDefaults()
	}
	delete := CommandLine.String("delete", "", "delete app <name>")
	create := CommandLine.String("create", "", "create app <name>")
	list := CommandLine.Bool("list", false, "list everything")
	err := CommandLine.Parse(os.Args[1:])
	if err != nil {
		log.Fatalf("ERROR: %v", err)
	}
	switch {
	case *delete != "":
		return deleteSettings(*delete)
	case *create != "":
		return createSettings(*create)
	case *list:
		return listSettings()
	default:
		CommandLine.Usage()
	}
	return "", errors.New("Invalid flag.")
}

func main() {
	result, err := switchByCommandLine()
	if err != nil {
		log.Fatalf("ERROR:\n%#v", err)
		fmt.Printf(result)
		log.Fatalf("ERROR (REPEATED):\n%#v", err)
		os.Exit(23)
	}
	fmt.Printf(result)
	os.Exit(0)
}