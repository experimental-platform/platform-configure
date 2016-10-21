package main

import (
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"path"
	"sort"
	"strings"
	"time"
)

var driver ZFSDriver

const timeFormat = "2006-01-02-15-04-05"

// The ZFSDriver interface describes a type that can be used to interact with the ZFS file system
type ZFSDriver interface {
	CreateSnapshots(names []string, label string) error
	Snapshots(filter string) ([]string, error)
	DeleteSnapshot(name string) error
	SendSnapshots(from, to string, output io.Writer) error
}

func init() {
	SetDriver(&GoZFS{})
}

// SetDriver sets a specific driver to be used to execute the zfs commands
func SetDriver(d ZFSDriver) {
	driver = d
}

// TakeSnapshot takes a snapshot from a dataset by its name with a label that's
// suffixed with the current timestamp in the format `-YYYY-MM-DD-HH-mm`
// The Keep argument defines how many versions of this snapshot should be kept
// is 0, all versions are kept
func TakeSnapshot(names []string, label string, keep int, send bool, dir string) error {
	oldSnapshots, err := Snapshots("")
	if err != nil {
		return err
	}

	labelWithTimestamp := fmt.Sprintf("%s-%s", label, time.Now().Format(timeFormat))
	newSnapshots := []string{}
	for _, n := range names {
		fullName := fmt.Sprintf("%s@%s", n, labelWithTimestamp)
		for _, ss := range oldSnapshots {
			if strings.HasSuffix(ss, fullName) {
				return fmt.Errorf("snapshot %s already exists", fullName)
			}
		}
		newSnapshots = append(newSnapshots, fullName)
	}

	if keep != 0 {
		cleanup(oldSnapshots, keep)
	}

	err = driver.CreateSnapshots(names, labelWithTimestamp)
	if err != nil {
		for _, n := range newSnapshots {
			_ = DeleteSnapshot(n)
		}
		return err
	}

	if send {
		err = sendSnapshots(names, label, labelWithTimestamp, dir)
		if err != nil {
			for _, n := range newSnapshots {
				_ = DeleteSnapshot(n)
			}
			return err
		}
	}

	return nil
}

func sendSnapshots(names []string, label, labelWithTimestamp, dir string) error {
	var err error
	var snapshotFiles []string
	for _, name := range names {
		nameWithoutSlashes := strings.Replace(name, "/", "-", -1)
		snapshotFile := fmt.Sprintf("%s-%s.snap", nameWithoutSlashes, labelWithTimestamp)
		var f *os.File
		f, err = os.Create(path.Join(dir, snapshotFile))
		if err != nil {
			break
		}
		defer f.Close()
		snapshotFiles = append(snapshotFiles, snapshotFile)

		var snapshots []string
		snapshots, err = driver.Snapshots(name)
		if err != nil {
			break
		}

		var from, to string
		from, to, err = newest(snapshots, name, label)
		if err != nil {
			break
		}

		err = driver.SendSnapshots(from, to, f)
		if err != nil {
			break
		}
		f.Sync()
	}

	if err != nil {
		log.Printf("error while sending snapshots. Cleaning up: %s", err)
		for _, file := range snapshotFiles {
			log.Printf("removing %s", file)
			os.Remove(file)
		}
	}

	return err
}

func newest(snapshots []string, name, label string) (from string, to string, err error) {
	var filtered []string
	prefix := fmt.Sprintf("%s@%s-", name, label)
	for _, s := range snapshots {
		if strings.HasPrefix(s, prefix) {
			filtered = append(filtered, s)
		}
	}

	sort.Strings(filtered)
	switch len(filtered) {
	case 0:
		err = errors.New("No snapshots found to send")
	case 1:
		to = filtered[0]
	default:
		from = filtered[len(filtered)-2]
		to = filtered[len(filtered)-1]
	}
	return from, to, err
}

func cleanup(snapshots []string, keep int) {
	if len(snapshots) < keep {
		return
	}

	sort.Strings(snapshots)
	for _, ss := range snapshots[:len(snapshots)-keep+1] {
		if err := DeleteSnapshot(ss); err != nil {
			log.Printf("Cleaning up snapshot %s didn't work: %s\n", ss, err)
		}
	}
}

// Snapshots lists returns all existing zfs snapshots. The filter
// argument is used to select snapshots matching a specific name.
// The empty string can be used to select all snapshots
func Snapshots(filter string) ([]string, error) {
	return driver.Snapshots(filter)
}

// DeleteSnapshot deletes a snapshot by its name
func DeleteSnapshot(name string) error {
	return driver.DeleteSnapshot(name)
}
