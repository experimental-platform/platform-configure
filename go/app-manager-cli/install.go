package main

import (
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"net/url"
	"os"

	"github.com/coreos/go-systemd/dbus"
	skvs "github.com/experimental-platform/platform-skvs/client"
)

func generatePassword() (string, error) {
	f, err := os.Open("/dev/urandom")
	if err != nil {
		return "", err
	}

	randomData := make([]byte, 1024)
	io.ReadFull(f, randomData)

	hash := sha256.Sum256(randomData)

	return fmt.Sprintf("%x", hash[:]), nil
}

func getOrGeneratePassword(skvsPath string) (string, error) {
	pass, err := skvs.Get(skvsPath)
	if err == nil {
		return pass, nil
	}

	if pass, err = generatePassword(); err != nil {
		return "", err
	}
	if err = skvs.Set(skvsPath, pass); err != nil {
		return "", err
	}

	return pass, nil
}

func fetchManifest(manifestURL string) (*appManifest, error) {
	parsedURL, err := url.Parse(manifestURL)
	if err == nil && len(parsedURL.Scheme) > 0 {
		return nil, errors.New("URLs are not yer supported")
	}

	manifestData, err := ioutil.ReadFile(manifestURL)
	if err != nil {
		return nil, err
	}

	var manifest appManifest

	if err = json.Unmarshal(manifestData, &manifest); err != nil {
		return nil, err
	}

	return &manifest, nil
}

func installAppFromURL(manifestURL string) error {
	manifest, err := fetchManifest(manifestURL)
	if err != nil {
		return err
	}

	return installAppFromManifest(manifest)
}

func installAppFromManifest(manifest *appManifest) error {
	if manifest.RequiresService("mysql") {
		_, err := prepareMySQL(manifest.ShortName)
		if err != nil {
			return err
		}
	}

	unitFileName := fmt.Sprintf("/etc/systemd/system/app-%s.service", manifest.ShortName)
	unitBody, err := generateUnitSerialized(manifest)
	if err != nil {
		return err
	}

	unitFile, err := os.OpenFile(unitFileName, os.O_CREATE|os.O_WRONLY|os.O_SYNC, 0644)
	if err != nil {
		return err
	}
	defer unitFile.Close()
	io.Copy(unitFile, unitBody)

	if manifest.RequiresService("redis") {
		redisUnitFileName := fmt.Sprintf("/etc/systemd/system/app-%s-redis.service", manifest.ShortName)
		redisUnitBody := generateRedisUnitSerialized(manifest.ShortName)

		var redisUnitFile *os.File
		redisUnitFile, err = os.OpenFile(redisUnitFileName, os.O_CREATE|os.O_WRONLY|os.O_SYNC, 0644)
		if err != nil {
			return err
		}
		defer redisUnitFile.Close()

		io.Copy(redisUnitFile, redisUnitBody)
	}

	if err = skvs.Set(fmt.Sprintf("apps/%s/enabled", manifest.ShortName), ""); err != nil {
		return err
	}

	conn, err := dbus.New()
	if err != nil {
		return err
	}

	if err = conn.Reload(); err != nil {
		return err
	}

	if _, err = conn.RestartUnit(fmt.Sprintf("app-%s.service", manifest.ShortName), "replace", nil); err != nil {
		return err
	}

	return nil
}
