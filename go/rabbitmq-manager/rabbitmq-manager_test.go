package main

import (
	"fmt"
	"net/http"
	"os"
	"strings"
	"testing"

	"github.com/michaelklishin/rabbit-hole"
)

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
	data        map[string]string
	callHistory map[string]int
}

func (rec *mocSKVS) Get(key string) (string, error) {
	rec.callHistory["Get"]++
	return rec.data[key], nil
}

func (rec *mocSKVS) Delete(key string) error {
	rec.callHistory["Delete"]++
	delete(rec.data, key)
	return nil
}

func (rec *mocSKVS) Set(key, value string) error {
	rec.callHistory["Set"]++
	rec.data[key] = value
	return nil
}

func newMocSKVS() (*mocSKVS, *map[string]int) {
	var moc mocSKVS
	moc.data = make(map[string]string)
	moc.callHistory = make(map[string]int)
	return &moc, &moc.callHistory
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
	var hist *map[string]int
	s, hist = newMocSKVS()
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
	if (*hist)["Delete"]+(*hist)["Set"] != 0 {
		t.Error("Write access to SKVS detected!")
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
	var hist *map[string]int
	s, hist = newMocSKVS()
	_, err := switchByCommandLine()
	if err != nil {
		t.Errorf("ERROR: %#v", err)
	}
	url, _ := s.Get(fmt.Sprintf("app/%s/rabbitmq", name))
	if !strings.Contains(url, name) {
		t.Errorf("Expected '%s' in url '%s'", name, url)
	}
	if (*hist)["Delete"]+(*hist)["Set"] == 0 {
		t.Error("Not writing to SKVS?")
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
	var hist *map[string]int
	s, hist = newMocSKVS()
	s.Set(fmt.Sprintf("app/%s/rabbitmq", name), "lalala")
	_, err := switchByCommandLine()
	if err != nil {
		t.Errorf("ERROR: %#v", err)
	}
	value, _ := s.Get(fmt.Sprintf("app/%s/rabbitmq", name))
	if value != "" {
		t.Errorf("App wasn't removed in SKVS: %#v: %#v", name, value)
	}
	if (*hist)["Delete"]+(*hist)["Set"] == 0 {
		t.Error("Not writing to SKVS?")
	}
	return
}
