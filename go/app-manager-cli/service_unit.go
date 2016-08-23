package main

import (
	"bytes"
	"fmt"
	"html/template"
	"io"

	"github.com/coreos/go-systemd/unit"
	skvs "github.com/experimental-platform/platform-skvs/client"
)

type unitEnvData struct {
	MySQL struct {
		Database string
		User     string
		Password string
	}
	SMTP struct {
		Host     string
		User     string
		Password string
	}
	LDAP struct {
		Base     string
		DN       string
		Password string
	}
	Hostname  string
	MyIP      string
	RedisHost string
}

func prepareEnvData(manifest *appManifest) (*unitEnvData, error) {
	var data unitEnvData

	if manifest.RequiresService("mysql") {
		data.MySQL.Database = manifest.ShortName
		data.MySQL.User = manifest.ShortName
		sqlPwd, err := skvs.Get(fmt.Sprintf("apps/%s/mysql_passwd", manifest.ShortName))
		if err != nil {
			return nil, err
		}
		data.MySQL.Password = sqlPwd
	}

	if manifest.RequiresService("smtp") {
		smtpHost, err := skvs.Get("smtp/host")
		if err != nil {
			return nil, err
		}
		smtpUser, err := skvs.Get("smtp/username")
		if err != nil {
			return nil, err
		}
		smtpPass, err := skvs.Get("smtp/password")
		if err != nil {
			return nil, err
		}

		data.SMTP.Host = smtpHost
		data.SMTP.User = smtpUser
		data.SMTP.Password = smtpPass
	}

	if manifest.RequiresService("ldap") {
		// TODO prepare some LDAP stuff
		data.LDAP.Base = "ou=People,dc=protonet,dc=com"
		data.LDAP.DN = fmt.Sprintf("uid=%s,ou=Apps,dc=protonet,dc=com", manifest.ShortName)
		data.LDAP.Password = "demo" // TODO actual password
	}

	if manifest.RequiresService("redis") {
		data.RedisHost = fmt.Sprintf("app-%s-redis", manifest.ShortName)
	}

	data.MyIP = fmt.Sprintf("$(/usr/bin/curl -X GET http://127.0.0.1:81/apps/%s/macvlan)", manifest.ShortName)

	hostname, err := skvs.Get("hostname")
	if err != nil {
		return nil, err
	}
	data.Hostname = hostname

	return &data, nil
}

func fillUnitWithEnvData(unitString string, envData *unitEnvData) (string, error) {
	bufferData := make([]byte, 0, 5120 /* 5KiB limit */)
	buffer := bytes.NewBuffer(bufferData)

	tmplForEnv, err := template.New("unit_with_env").Parse(unitString)
	if err != nil {
		return "", err
	}

	err = tmplForEnv.Execute(buffer, envData)
	if err != nil {
		return "", err
	}

	return buffer.String(), nil
}

func generateDockerRunCommand(manifest *appManifest) (string, error) {
	appendPreLine := func(s *string, newPart string) { *s = fmt.Sprintf("%s%s \\\n", *s, newPart) }
	envData, err := prepareEnvData(manifest)
	if err != nil {
		return "", err
	}
	myIPGetterString := fmt.Sprintf("$(/usr/bin/curl -X GET http://127.0.0.1:81/apps/%s/macvlan)", manifest.ShortName)

	var s string
	appendPreLine(&s, "/usr/bin/env bash -c \"/usr/bin/docker run -d")
	appendPreLine(&s, "    --name app-"+manifest.ShortName)
	appendPreLine(&s, "    --net=protonet")
	for volName, volPath := range manifest.DataVolumes {
		appendPreLine(&s, fmt.Sprintf("    --volume /data/app/%s/%s:%s", manifest.ShortName, volName, volPath))
	}
	for portKey, portVal := range manifest.PortMappings {
		appendPreLine(&s, fmt.Sprintf(`    --publish \"%s:%s:%s\"`, myIPGetterString, portKey, portVal))
	}
	for envKey, envVal := range manifest.Env {
		appendPreLine(&s, fmt.Sprintf(`    --env \"%s=%s\"`, envKey, envVal))
	}

	s = fmt.Sprintf("%s    %s:%s\"", s, manifest.DockerImageName, manifest.DockerImageTag)

	filledUnit, err := fillUnitWithEnvData(s, envData)
	if err != nil {
		return "", err
	}

	return filledUnit, nil
}

func generateUnitSerialized(manifest *appManifest) (io.Reader, error) {
	var opts []*unit.UnitOption

	// [Unit]
	opts = append(opts, unit.NewUnitOption("Unit", "Description", fmt.Sprintf("%s application", manifest.FullName)))

	opts = append(opts, unit.NewUnitOption("Unit", "After", "init-protonet.service"))
	if manifest.RequiresService("redis") {
		opts = append(opts, unit.NewUnitOption("Unit", "After", fmt.Sprintf("app-%s-redis.service", manifest.ShortName)))
	}
	if manifest.RequiresService("ldap") {
		opts = append(opts, unit.NewUnitOption("Unit", "After", "platform-ldap.service"))
	}

	opts = append(opts, unit.NewUnitOption("Unit", "Requires", "init-protonet.service"))
	if manifest.RequiresService("redis") {
		opts = append(opts, unit.NewUnitOption("Unit", "Requires", fmt.Sprintf("app-%s-redis.service", manifest.ShortName)))
	}
	if manifest.RequiresService("ldap") {
		opts = append(opts, unit.NewUnitOption("Unit", "Wants", "platform-ldap.service"))
	}

	// [Service]
	opts = append(opts, unit.NewUnitOption("Service", "TimeoutStartSec", "0"))
	opts = append(opts, unit.NewUnitOption("Service", "TimeoutStopSec", "15"))
	opts = append(opts, unit.NewUnitOption("Service", "Restart", "always"))
	opts = append(opts, unit.NewUnitOption("Service", "RestartSec", "5s"))
	for dvName := range manifest.DataVolumes {
		opts = append(opts, unit.NewUnitOption("Service", "ExecStartPre", fmt.Sprintf("/usr/bin/mkdir -p /data/app/%s/%s", manifest.ShortName, dvName)))
	}
	opts = append(opts, unit.NewUnitOption("Service", "ExecStartPre", fmt.Sprintf("/usr/bin/curl -X POST http://127.0.0.1:81/apps/%s/macvlan", manifest.ShortName)))
	opts = append(opts, unit.NewUnitOption("Service", "ExecStartPre", fmt.Sprintf("-/usr/bin/docker rm -f app-%s", manifest.ShortName)))

	runCommand, err := generateDockerRunCommand(manifest)
	if err != nil {
		return nil, err
	}
	opts = append(opts, unit.NewUnitOption("Service", "ExecStartPre", runCommand))

	opts = append(opts, unit.NewUnitOption("Service", "ExecStart", fmt.Sprintf("/usr/bin/docker logs -f app-%s", manifest.ShortName)))
	opts = append(opts, unit.NewUnitOption("Service", "ExecStop", fmt.Sprintf("/usr/bin/docker stop app-%s", manifest.ShortName)))
	opts = append(opts, unit.NewUnitOption("Service", "ExecStopPost", fmt.Sprintf("/usr/bin/docker stop app-%s", manifest.ShortName)))

	// [Install]
	opts = append(opts, unit.NewUnitOption("Install", "WantedBy", "multi-user.target"))

	return unit.Serialize(opts), nil
}
