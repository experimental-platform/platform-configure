package main

import (
	"fmt"
	"github.com/michaelklishin/rabbit-hole"
	"net/http"
	"os"
	"strings"
	"testing"
)

// import "testing"

type mocRabbit struct {
	PutVhostData             *http.Response
	PutVhostError            error
	DeleteVhostData          *http.Response
	DeleteVhostError         error
	PutUserData              *http.Response
	PutUserError             error
	DeleteUserData           *http.Response
	DeleteUserError          error
	UpdatePermissionsInData  *http.Response
	UpdatePermissionsInError error
	ListPermissionsData      []rabbithole.PermissionInfo
	ListPermissionsError     error
}

func (rec mocRabbit) PutVhost(a string, b rabbithole.VhostSettings) (*http.Response, error) {
	return rec.PutVhostData, rec.PutVhostError
}

func (rec mocRabbit) DeleteVhost(a string) (*http.Response, error) {
	return rec.DeleteVhostData, rec.DeleteVhostError
}

func (rec mocRabbit) PutUser(a string, b rabbithole.UserSettings) (*http.Response, error) {
	return rec.PutUserData, rec.PutUserError
}

func (rec mocRabbit) DeleteUser(a string) (*http.Response, error) {
	return rec.DeleteUserData, rec.DeleteUserError
}

func (rec mocRabbit) UpdatePermissionsIn(a string, b string, c rabbithole.Permissions) (*http.Response, error) {
	return rec.UpdatePermissionsInData, rec.UpdatePermissionsInError
}

func (rec mocRabbit) ListPermissions() ([]rabbithole.PermissionInfo, error) {
	return rec.ListPermissionsData, rec.ListPermissionsError
}

type mocSKVS struct {
	data map[string]string
}

func (rec *mocSKVS) Get(key string) (string, error) {
	return rec.data[key], nil
}

func (rec *mocSKVS) Delete(key string) error {
	delete(rec.data, key)
	return nil
}

func (rec *mocSKVS) Set(key, value string) error {
	rec.data[key] = value
	return nil
}

func newMocSKVS() *mocSKVS {
	var bla mocSKVS
	bla.data = make(map[string]string)
	return &bla
}

func TestListSettings(t *testing.T) {
	oldArgs := os.Args
	defer func() {
		os.Args = oldArgs
	}()
	os.Args = []string{"foobar", "-list"}
	username := "blafasel"
	vhost := "/testtesttest"
	r = mocRabbit{ListPermissionsData: []rabbithole.PermissionInfo{{
		User:      username,
		Vhost:     vhost,
		Configure: ".*",
		Write:     ".*",
		Read:      ".*"},
	}}
	s = newMocSKVS()
	result, err := switchByCommandLine()
	if err != nil {
		t.Errorf("ERROR: %#v", err)
	}
	if !strings.Contains(result, vhost) {
		t.Errorf("Expected '%s' to contain '%s'", result, vhost)
	}
	if !strings.Contains(result, username) {
		t.Errorf("Expected '%s' to contain '%s'", result, username)
	}
	return
}

func TestCreate(t *testing.T) {
	oldArgs := os.Args
	defer func() {
		os.Args = oldArgs
	}()
	name := "blupp"
	os.Args = []string{"foobar", "-create", name}
	r = mocRabbit{}
	s = newMocSKVS()
	_, err := switchByCommandLine()
	if err != nil {
		t.Errorf("ERROR: %#v", err)
	}
	url, _ := s.Get(fmt.Sprintf("app/%s/rabbitmq", name))
	if !strings.Contains(url, name) {
		t.Errorf("Expected '%s' in url '%s'", name, url)
	}
	return
}

func TestDelete(t *testing.T) {
	oldArgs := os.Args
	defer func() {
		os.Args = oldArgs
	}()
	name := "blupp"
	os.Args = []string{"foobar", "-delete", name}
	r = mocRabbit{}
	s = newMocSKVS()
	s.Set(fmt.Sprintf("app/%s/rabbitmq", name), "lalala")
	_, err := switchByCommandLine()
	if err != nil {
		t.Errorf("ERROR: %#v", err)
	}
	value, _ := s.Get(fmt.Sprintf("app/%s/rabbitmq", name))
	if value != "" {
		t.Errorf("App wasn't removed in SKVS: %#v", value)
	}
	return
}
