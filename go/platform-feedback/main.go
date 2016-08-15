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

func tarFeedbackFile(dir string, fileinfo os.FileInfo, tarWriter *tar.Writer) error {
	fullPath := fmt.Sprintf("%s/%s", dir, fileinfo.Name())
	file, err := os.Open(fullPath)
	if err != nil {
		return err
	}

	header := tar.Header{
		Gid:  os.Getgid(),
		Uid:  os.Getuid(),
		Name: fileinfo.Name(),
		Size: fileinfo.Size(),
		Mode: 0644,
	}

	err = tarWriter.WriteHeader(&header)
	if err != nil {
		return err
	}

	_, err = io.Copy(tarWriter, file)
	if err != nil {
		return err
	}

	return nil
}

func tarTheData(dir string) (string, error) {
	timestamp := time.Now().UTC().Format("2006-01-02_15:04:05")
	filename := fmt.Sprintf("%s-%s-platform-feedback.tar.gz", timestamp, getHostname())

	archiveFile, err := os.OpenFile(filename, os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return "", err
	}
	defer archiveFile.Close()
	defer archiveFile.Sync()

	compressor := gzip.NewWriter(archiveFile)
	defer compressor.Close()
	defer compressor.Flush()

	tarWriter := tar.NewWriter(compressor)
	defer tarWriter.Close()
	defer tarWriter.Flush()

	list, err := ioutil.ReadDir(dir)
	if err != nil {
		return "", err
	}

	for _, file := range list {
		err = tarFeedbackFile(dir, file, tarWriter)
		if err != nil {
			return "", fmt.Errorf("Error archiving the feedback data: %s", err.Error())
		}
	}

	return filename, nil
}

func main() {
	dir, err := ioutil.TempDir("", "platform-feedback")
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("Work directory: %s", dir)

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

	archiveName, err := tarTheData(dir)
	if err != nil {
		log.Fatal(err)
	}

	os.RemoveAll(dir)

	log.Printf("\n\n\nPLEASE SEND '%s' TO YOUR FRIENDLY SUPPORT TEAM. THANK YOU\n", archiveName)
}
