package main

import (
	"flag"
	"fmt"
	"log"
	"os"
)

var keep = flag.Int("keep", 0, "how many versions of the snapshot to keep. 0 means don't cleanup any old snapshots")
var label = flag.String("label", "backup", "the name of the snapshot label")
var send = flag.Bool("send", false, "wether or not to dump the snapshot to disk")
var snapshotDir = flag.String("dir", ".", "which directory to dump the snapshot to")

func main() {
	var err error

	flag.Parse()
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s [-label string] [-keep int] command [create|delete|list] name(s):\n", os.Args[0])
		flag.PrintDefaults()
	}
	cmd := flag.Arg(0)
	names := flag.Args()[1:]

	switch cmd {
	case "create":
		if len(names) < 1 {
			flag.Usage()
			os.Exit(1)
		}
		err = TakeSnapshot(names, *label, *keep, *send, *snapshotDir)
	case "delete":
		if len(names) != 1 {
			flag.Usage()
			os.Exit(1)
		}
		err = DeleteSnapshot(names[0])
	case "list":
		var snapshots []string
		snapshots, err = Snapshots("")
		if err != nil {
			log.Fatal(err)
		}

		for _, ss := range snapshots {
			fmt.Println(ss)
		}
	default:
		flag.Usage()
	}

	if err != nil {
		log.Fatal(err)
	}
}
