package main

import (
	"bytes"
	"errors"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"text/template"
	"time"

	skvs "github.com/experimental-platform/platform-skvs/client"
	"github.com/experimental-platform/platform-utils/dockerutil"
	"github.com/michaelklishin/rabbit-hole"
)

// where RabbitMQ lives in SKVS
var RabbitSKVS string = "rabbitmq"

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

func getOrCreateCredentials() (string, string) {
	user, err := s.Get(fmt.Sprintf("%s/user", RabbitSKVS))
	if err != nil {
		user = "guest"
	}
	passwd, err := s.Get(fmt.Sprintf("%s/passwd", RabbitSKVS))
	if err != nil {
		passwd = "guest"
	}
	return user, passwd
}

func (rec *realRabbit) connect() {
	if rec.con == nil {
		// get rabbitmq IP address
		host, err := dockerutil.GetContainerIP("rabbitmq")
		if err != nil {
			panic(err)
		}
		host = fmt.Sprintf("http://%s:15672", host)
		user, passwd := getOrCreateCredentials()
		if err != nil {
			panic(err)
		}
		// RabbitMQ is slow *and* starts to listen prior to being fully running, so we
		// try this 10 times and wait a sec between each try.
		var i int
		for i = 0; i < 200; i++ {
			rec.con, err = rabbithole.NewClient(host, user, passwd)
			if err == nil {
				_, err = rec.con.ListNodes()
				if err == nil {
					fmt.Printf("Success on %d of 100.\n", i)
					return
				}
			}
			time.Sleep(3 * time.Second)
		}
		fmt.Printf("NO WAY TO CONNECT, GIVING UP AFTER %d ATTEMPTS.\n", i)
		panic(err)
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
	const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
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

func updatePermissions(name, vhost string) error {
	permissions := rabbithole.Permissions{
		Read:      ".*",
		Write:     ".*",
		Configure: ".*",
	}
	_, err := r.UpdatePermissionsIn(vhost, name, permissions)
	return err
}

func createSettings(name, vhost string) (string, error) {
	password, err := createUser(name)
	if err != nil {
		panic(err)
	}
	err = createVHost(vhost)
	if err != nil {
		panic(err)
	}
	err = updatePermissions(name, vhost)
	if err != nil {
		panic(err)
	}
	// write user, password and vhost to SKVS
	key := fmt.Sprintf("app/%s/rabbitmq", vhost)
	url := fmt.Sprintf("amqp://%s:%s@rabbitmq:5672/%s", name, password, vhost)
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
		return createSettings(*create, *create)
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
		log.Fatalf("ERROR:\n%#v\n", err)
	}
	fmt.Printf(result)
	os.Exit(0)
}
