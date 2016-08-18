package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"os"

	"net/http"
	"net/url"

	"github.com/docker/engine-api/client"
	"github.com/docker/engine-api/types"
	"github.com/docker/engine-api/types/filters"
	"golang.org/x/net/context"
)

type skvsResponse struct {
	Key       string `json:"key"`
	Namespace bool   `json:"namespace"`
	Value     string `json:"value"`
}

func printUsage() {
	fmt.Fprintf(os.Stderr, "Usage: %s OPERATION [PARAMS]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "\nSupported operations:\n")
	fmt.Fprintf(os.Stderr, "\tget KEY\n")
	fmt.Fprintf(os.Stderr, "\tset KEY VALUE\n")
	fmt.Fprintf(os.Stderr, "\tdelete KEY\n")
}

func invalidParameters() {
	printUsage()
	os.Exit(1)
}

func getSKVSIP() (string, error) {
	defaultHeaders := map[string]string{"User-Agent": "protonet-skvs_cli"}
	cli, err := client.NewClient("unix:///var/run/docker.sock", "v1.22", nil, defaultHeaders)
	if err != nil {
		return "", err
	}

	listOptions := types.ContainerListOptions{Filter: filters.NewArgs()}
	listOptions.Filter.Add("name", "skvs")

	containers, err := cli.ContainerList(context.Background(), listOptions)
	if err != nil {
		return "", err
	}
	if len(containers) == 0 {
		return "", errors.New("Found no container named 'skvs'")
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

func get(key string) (string, error) {
	ip, err := getSKVSIP()
	if err != nil {
		return "", err
	}

	requestURL := fmt.Sprintf("http://%s/%s", ip, key)
	resp, err := http.Get(requestURL)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("SKVS responded with %s", resp.Status)
	}

	responseBodyData, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var responseStruct skvsResponse

	err = json.Unmarshal(responseBodyData, &responseStruct)
	if err != nil {
		return "", err
	}

	return responseStruct.Value, nil
}

func set(key string, value string) error {
	ip, err := getSKVSIP()
	if err != nil {
		return err
	}

	requestURL := fmt.Sprintf("http://%s/%s", ip, key)
	vals := url.Values{}
	vals.Set("value", value)
	resp, err := http.PostForm(requestURL, vals)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("SKVS responded with %s", resp.Status)
	}

	return nil
}

func delete(key string) error {
	ip, err := getSKVSIP()
	if err != nil {
		return err
	}

	requestURL := fmt.Sprintf("http://%s/%s", ip, key)
	req, err := http.NewRequest("DELETE", requestURL, nil)
	if err != nil {
		return err
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("SKVS responded with %s", resp.Status)
	}

	return nil
}

func main() {
	if len(os.Args) < 2 {
		invalidParameters()
	}

	switch os.Args[1] {
	case "get":
		if len(os.Args) != 3 {
			invalidParameters()
		}
		value, err := get(os.Args[2])
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
		fmt.Print(value)
		break
	case "delete":
		if len(os.Args) != 3 {
			invalidParameters()
		}
		err := delete(os.Args[2])
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
		break
	case "set":
		if len(os.Args) != 4 {
			invalidParameters()
		}
		err := set(os.Args[2], os.Args[3])
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
		break
	case "--help":
		printUsage()
		break
	case "-h":
		printUsage()
		break
	default:
		invalidParameters()
		break
	}
}
