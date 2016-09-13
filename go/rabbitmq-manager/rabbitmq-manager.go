package main

import (
	"bytes"
	"errors"
	"flag"
	"fmt"
	skvs "github.com/experimental-platform/platform-skvs/client"
	"github.com/experimental-platform/platform-utils/dockerutil"
	"github.com/michaelklishin/rabbit-hole"
	"log"
	"math/rand"
	"net/http"
	"os"
	"text/template"
	"time"
)

type rabbitConnector interface {
	PutVhost(string, rabbithole.VhostSettings) (*http.Response, error)
	DeleteVhost(string) (*http.Response, error)
	PutUser(string, rabbithole.UserSettings) (*http.Response, error)
	DeleteUser(string) (*http.Response, error)
	UpdatePermissionsIn(string, string, rabbithole.Permissions) (*http.Response, error)
	ListPermissions() ([]rabbithole.PermissionInfo, error)
}

type realRabbit struct {
	con *rabbithole.Client
}

func (rec *realRabbit) connect() {
	if rec.con == nil {
		// TODO: get host, user and password from skvs
		host, err := dockerutil.GetContainerIP("rabbitmq")
		if err != nil {
			// TODO: THIS IS BULLSHIT!
			host = "127.0.0.1"
		}
		con, err := rabbithole.NewClient(fmt.Sprintf("http://%s:15672", host), "guest", "guest")
		if err != nil {
			panic(err)
		}
		rec.con = con
	}
	return
}

func (rec *realRabbit) PutVhost(a string, b rabbithole.VhostSettings) (*http.Response, error) {
	rec.connect()
	return rec.con.PutVhost(a, b)
}

func (rec *realRabbit) DeleteVhost(a string) (*http.Response, error) {
	rec.connect()
	return rec.con.DeleteVhost(a)
}

func (rec *realRabbit) PutUser(a string, b rabbithole.UserSettings) (*http.Response, error) {
	rec.connect()
	return rec.con.PutUser(a, b)
}

func (rec *realRabbit) DeleteUser(a string) (*http.Response, error) {
	rec.connect()
	return rec.con.DeleteUser(a)
}

func (rec *realRabbit) UpdatePermissionsIn(a string, b string, c rabbithole.Permissions) (*http.Response, error) {
	rec.connect()
	return rec.con.UpdatePermissionsIn(a, b, c)
}

func (rec *realRabbit) ListPermissions() ([]rabbithole.PermissionInfo, error) {
	rec.connect()
	return rec.con.ListPermissions()
}

var r rabbitConnector = new(realRabbit)

type skvsConnector interface {
	Delete(string) error
	Get(string) (string, error)
	Set(string, string) error
}

type realSKVS struct{}

func (rec *realSKVS) Delete(key string) error {
	return skvs.Delete(key)
}

func (rec *realSKVS) Get(key string) (string, error) {
	return skvs.Get(key)
}

func (rec *realSKVS) Set(key, value string) error {
	return skvs.Set(key, value)
}

var s skvsConnector = new(realSKVS)

func deleteSettings(name string) (string, error) {
	_, err := r.DeleteVhost(name)
	if err != nil {
		fmt.Printf("ERROR DELETING VHOST: %v", err)
	}
	_, err = r.DeleteUser(name)
	if err != nil {
		fmt.Printf("ERROR DELETING USER: %v", err)
	}
	// delete url from SKVS
	key := fmt.Sprintf("app/%s/rabbitmq", name)
	err = s.Delete(key)
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
	// create password and (update or create) user
	password := randomString(20)
	userInfo := rabbithole.UserSettings{
		Name:     name,
		Password: password,
		Tags:     "autocreated",
	}
	_, err := r.PutUser(name, userInfo)
	return password, err
}

func createVHost(name string) error {
	vhostSetting := rabbithole.VhostSettings{}
	_, err := r.PutVhost(name, vhostSetting)
	return err
}

func updatePermissions(name string) error {
	permissions := rabbithole.Permissions{
		Read:      ".*",
		Write:     ".*",
		Configure: ".*",
	}
	_, err := r.UpdatePermissionsIn(name, name, permissions)
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
	err = s.Set(key, url)
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
	perms, err := r.ListPermissions()
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
