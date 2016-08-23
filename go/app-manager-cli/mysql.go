package main

import (
	"errors"
	"fmt"

	"github.com/docker/engine-api/client"
	"github.com/docker/engine-api/types"
	"github.com/docker/engine-api/types/filters"
	"golang.org/x/net/context"
)

func getMySQLIP() (string, error) {
	defaultHeaders := map[string]string{"User-Agent": "protonet-app-manager-cli"}
	cli, err := client.NewClient("unix:///var/run/docker.sock", "v1.22", nil, defaultHeaders)
	if err != nil {
		return "", err
	}

	listOptions := types.ContainerListOptions{Filter: filters.NewArgs()}
	listOptions.Filter.Add("name", "mysql")

	containers, err := cli.ContainerList(context.Background(), listOptions)
	if err != nil {
		return "", err
	}
	if len(containers) == 0 {
		return "", errors.New("Found no container named 'mysql'")
	}

	data, err := cli.ContainerInspect(context.Background(), containers[0].ID)
	if err != nil {
		return "", err
	}

	protonetNetworkData, ok := data.NetworkSettings.Networks["protonet"]
	if !ok {
		return "", errors.New("The SKVS container doesn't belong to the network 'protonet'.")
	}

	return protonetNetworkData.IPAddress, nil
}

// prepareMySQL prepares a database for an app and returns the password
func prepareMySQL(appname string) (string, error) {
	defaultHeaders := map[string]string{"User-Agent": "protonet-app-manager-cli"}
	cli, err := client.NewClient("unix:///var/run/docker.sock", "v1.22", nil, defaultHeaders)
	if err != nil {
		return "", err
	}

	sqlPassword, err := getOrGeneratePassword(fmt.Sprintf("apps/%s/mysql_passwd", appname))
	if err != nil {
		return "", err
	}

	listOptions := types.ContainerListOptions{Filter: filters.NewArgs()}
	listOptions.Filter.Add("name", "mysql")

	containers, err := cli.ContainerList(context.Background(), listOptions)
	if err != nil {
		return "", err
	}
	if len(containers) == 0 {
		return "", errors.New("Found no container named 'mysql'")
	}

	query := fmt.Sprintf(`CREATE DATABASE IF NOT EXISTS %s DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
	CREATE USER IF NOT EXISTS '%s'@'%%';
	SET PASSWORD FOR '%s'@'%%' = PASSWORD('%s');
	GRANT ALL PRIVILEGES ON %s.* TO '%s'@'%%';`, appname, appname, appname, sqlPassword, appname, appname)

	execConfig := types.ExecConfig{
		AttachStderr: true,
		AttachStdout: true,
		Cmd:          []string{"mysql", "--password=s3kr3t", "--batch", "-e", query},
	}

	exec, err := cli.ContainerExecCreate(context.Background(), containers[0].ID, execConfig)
	if err != nil {
		return "", err
	}

	err = cli.ContainerExecStart(context.Background(), exec.ID, types.ExecStartCheck{})
	if err != nil {
		return "", err
	}

	return sqlPassword, nil
}
