// +build !linux

package main

// default is mock, so we can run on Darwin and Windows without killing those.
var nl NetLink = mocNL{}
var nu NetUtil = mocNU{}
