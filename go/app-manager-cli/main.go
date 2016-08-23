package main

import (
	"fmt"
	"os"
)

func printUsage() {

}

func main() {
	if len(os.Args) == 1 {
		printUsage()
		os.Exit(1)
	}

	switch os.Args[1] {
	case "install":
		if len(os.Args) < 3 {
			printUsage()
			os.Exit(1)
		}

		err := installAppFromURL(os.Args[2])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Println("Installation successful")
		break
	default:
		fmt.Fprintf(os.Stderr, "Unknown action '%s'\n", os.Args[1])
	}
}
