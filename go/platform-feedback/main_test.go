package main

import (
	"archive/tar"
	"compress/gzip"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strings"
	"testing"
)

func TestGetHostname(t *testing.T) {
	cmd := exec.Command("hostname")

	result, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatal(err)
	}

	functionHostname := getHostname()
	cmdHostname := strings.Trim(string(result), "\n")

	if functionHostname != cmdHostname {
		t.Fatalf("Got hostname '%s', but command `hostname` returned '%s'", functionHostname, cmdHostname)
	}
}

func TestGetCommandsOutput(t *testing.T) {
	dir, err := ioutil.TempDir("", "platform-feedback-test")
	if err != nil {
		log.Fatal(err)
	}
	defer os.RemoveAll(dir)

	testString := "testing testy tests"
	err = getCommandsOutput(true, dir, "foobar", "echo", "-n", testString)
	if err != nil {
		log.Fatal(err)
	}

	data, err := ioutil.ReadFile(fmt.Sprintf("%s/foobar.txt", dir))
	if err != nil {
		t.Fatal(err)
	}

	stringRead := string(data)

	if stringRead != testString {
		t.Fatalf("Expected string '%s', read '%s'", testString, stringRead)
	}
}

func TestTarTheData(t *testing.T) {
	workDir, err := ioutil.TempDir("", "platform-feedback-test")
	if err != nil {
		log.Fatal(err)
	}
	defer os.RemoveAll(workDir)

	tempDir, err := ioutil.TempDir("", "platform-feedback-test")
	if err != nil {
		log.Fatal(err)
	}
	defer os.RemoveAll(tempDir)

	currentWorkingDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(currentWorkingDir)

	err = os.Chdir(workDir)
	if err != nil {
		t.Fatal(err)
	}

	testString := "testing testy tests"
	err = getCommandsOutput(true, tempDir, "foobar", "echo", "-n", testString)
	if err != nil {
		log.Fatal(err)
	}

	outputFileName, err := tarTheData(tempDir)
	if err != nil {
		log.Fatal(err)
	}

	fileHandle, err := os.Open(fmt.Sprintf("%s/%s", workDir, outputFileName))
	if err != nil {
		t.Fatal(err)
	}
	defer fileHandle.Close()

	decompressor, err := gzip.NewReader(fileHandle)
	if err != nil {
		t.Fatal(err)
	}
	defer decompressor.Close()

	tarReader := tar.NewReader(decompressor)
	fileHeader, err := tarReader.Next()
	if err != nil {
		t.Fatal(err)
	}

	if fileHeader.Name != "foobar.txt" {
		t.Fatalf("Expected filename 'foobar.txt', found '%s'", fileHeader.Name)
	}

	if int(fileHeader.Size) != len(testString) {
		t.Fatalf("Expected file size %d, got %d", len(testString), fileHeader.Size)
	}

	readData, err := ioutil.ReadAll(tarReader)
	if err != nil {
		t.Fatal(err)
	}

	readString := string(readData)

	if readString != testString {
		t.Fatalf("Expected file content '%s', read '%s'", testString, readString)
	}

	_, err = tarReader.Next()

	if err != io.EOF {
		t.Fatal("Expected end of archive, found a next file instead")
	}
}
