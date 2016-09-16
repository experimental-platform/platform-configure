package main

import (
	"fmt"
	"os"

	"strings"

	skvs "github.com/experimental-platform/platform-skvs/client"
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

func main() {
	if len(os.Args) < 2 {
		invalidParameters()
	}

	switch strings.ToLower(os.Args[1]) {
	case "get":
		if len(os.Args) != 3 {
			invalidParameters()
		}
		value, err := skvs.Get(os.Args[2])
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
		fmt.Print(value)
	case "delete":
		if len(os.Args) != 3 {
			invalidParameters()
		}
		err := skvs.Delete(os.Args[2])
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
	case "set":
		if len(os.Args) != 4 {
			invalidParameters()
		}
		err := skvs.Set(os.Args[2], os.Args[3])
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
	case "--help", "-h", "help":
		printUsage()
	default:
		invalidParameters()
	}
}
