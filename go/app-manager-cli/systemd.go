package main

import (
	"fmt"

	"github.com/coreos/go.dbus"
)

func systemdDaemonReload() error {
	conn, err := dbus.SystemBus()
	if err != nil {
		return fmt.Errorf("Failed to connect to session bus: %s", err.Error())
	}

	object := conn.Object("org.freedesktop.systemd1", "/org/freedesktop/systemd1")
	call := object.Call("org.freedesktop.systemd1.Manager.Reload", 0)

	if call.Err != nil {
		return call.Err
	}

	return nil
}
