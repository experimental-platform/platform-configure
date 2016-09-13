package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"time"
)

func getFailedUnits() ([]string, error) {
	cmd := exec.Command("systemctl", "--failed", "--no-legend")
	data, err := cmd.CombinedOutput()
	if err != nil {
		return nil, err
	}

	buffer := bytes.NewBuffer(data)

	var failedUnits []string

	for {
		line, err := buffer.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				splitLine := strings.Split(line, " ")
				failedUnits = append(failedUnits, splitLine[0])
				return failedUnits, nil
			}

			return nil, err
		}

		splitLine := strings.Split(line, " ")
		failedUnits = append(failedUnits, splitLine[0])
		return failedUnits, nil
	}
}

func getCommandsOutput(canFail bool, dir, file, command string, params ...string) error {
	cmd := exec.Command(command, params...)

	cmdOutPath := fmt.Sprintf("%s/%s.txt", dir, file)
	cmdOutFile, err := os.OpenFile(cmdOutPath, os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0644)
	if err != nil {
		log.Printf("Failed to open '%s'", cmdOutPath)
		return err
	}
	defer cmdOutFile.Close()

	cmd.Stdout = cmdOutFile
	cmd.Stderr = cmdOutFile

	err = cmd.Run()
	if err != nil {
		if canFail == false {
			log.Printf("Running '%s' for file '%s' failed: %s", command, file, err.Error())
		}
		return err
	}

	return nil
}

func getHostname() string {
	defaultHostname := "protonet"
	hostname, err := os.Hostname()
	if err != nil {
		log.Printf("Error getting system hostname, defaulting to '%s'", defaultHostname)
		return defaultHostname
	}

	return hostname
}

func tarFeedbackFile(path, relativePath string, info os.FileInfo, tarWriter *tar.Writer) error {
	isDir := info.IsDir()

	header, err := tar.FileInfoHeader(info, relativePath)
	if err != nil {
		return err
	}

	header.Name = relativePath

	err = tarWriter.WriteHeader(header)
	if err != nil {
		return err
	}

	if !isDir {
		file, err := os.Open(path)
		if err != nil {
			return err
		}

		_, err = io.Copy(tarWriter, file)
		if err != nil {
			return err
		}
	}

	return nil
}

func tarTheData(dir, prefix string, tarWriter *tar.Writer) error {
	walkFn := func(path string, info os.FileInfo, err error) error {
		relativePath, err := filepath.Rel(dir, path)
		if err != nil {
			return err
		}

		if relativePath == "." {
			return nil
		}

		if len(prefix) > 0 {
			relativePath = fmt.Sprintf("%s/%s", prefix, relativePath)
		}

		err = tarFeedbackFile(path, relativePath, info, tarWriter)
		if err != nil {
			return fmt.Errorf("Error archiving the feedback data: %s", err.Error())
		}

		return nil
	}

	err := filepath.Walk(dir, walkFn)

	return err
}

func createOutputArchive() (string, *os.File, *gzip.Writer, *tar.Writer, error) {
	timestamp := time.Now().UTC().Format("2006-01-02_15:04:05")
	filename := fmt.Sprintf("%s-%s-platform-feedback.tar.gz", timestamp, getHostname())

	archiveFile, err := os.OpenFile(filename, os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return "", nil, nil, nil, err
	}

	compressor := gzip.NewWriter(archiveFile)
	tarWriter := tar.NewWriter(compressor)

	return filename, archiveFile, compressor, tarWriter, nil
}

func bailIfNotRoot() {
	if os.Getuid() != 0 {
		log.Fatal("You must run this as root")
	}
}

func rmOutOnCtrlC(path string) {
	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, os.Interrupt)
	go func() {
		for _ = range signalChan {
			log.Println("Received user interrupt, cleaning up output")
			os.Remove(path)
			os.Exit(1)
		}
	}()
}

func main() {
	bailIfNotRoot()

	dir, err := ioutil.TempDir("", "platform-feedback")
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("Work directory: %s", dir)

	archiveName, archiveFile, compressor, tarWriter, err := createOutputArchive()
	if err != nil {
		log.Fatal(err)
	}
	rmOutOnCtrlC(archiveName)

	defer archiveFile.Close()
	defer archiveFile.Sync()
	defer compressor.Close()
	defer compressor.Flush()
	defer tarWriter.Close()
	defer tarWriter.Flush()

	getCommandsOutput(false, dir, "disk-free-space", "df", "-h")
	getCommandsOutput(false, dir, "disk-free-inodes", "df", "-i")
	getCommandsOutput(false, dir, "dmesg", "dmesg")
	getCommandsOutput(false, dir, "systemd-service-list", "systemctl", "-a")

	failedUnits, err := getFailedUnits()
	if err != nil {
		log.Printf("Getting failed units failed: %s", err.Error())
	}

	for _, u := range failedUnits {
		getCommandsOutput(true, dir, "systemd-service-status-failed", "systemctl", "status", u)
	}

	getCommandsOutput(false, dir, "current-log", "journalctl", "-b")
	getCommandsOutput(false, dir, "previous-log", "journalctl", "-b", "-1")

	getCommandsOutput(false, dir, "docker-ps-a", "docker", "ps", "-a")
	getCommandsOutput(false, dir, "docker-images", "docker", "images")

	getCommandsOutput(false, dir, "zpool-list", "zpool", "list")
	getCommandsOutput(false, dir, "zpool-status", "zpool", "status")
	getCommandsOutput(false, dir, "zpool-get-all", "zpool", "get", "all")
	getCommandsOutput(false, dir, "zpool-history", "zpool", "history")
	getCommandsOutput(false, dir, "zpool-events", "zpool", "events")
	getCommandsOutput(false, dir, "zfs-list", "zfs", "list")
	getCommandsOutput(false, dir, "zfs-get-all", "zfs", "get", "all")

	err = tarTheData(dir, "", tarWriter)
	if err != nil {
		log.Fatal(err)
	}

	err = tarTheData("/data/collectd", "collectd", tarWriter)
	if err != nil {
		log.Fatal(err)
	}

	os.RemoveAll(dir)

	log.Printf("\n\n\nPLEASE SEND '%s' TO YOUR FRIENDLY SUPPORT TEAM. THANK YOU\n", archiveName)
}
