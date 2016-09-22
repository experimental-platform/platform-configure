// +build !linux

package main

// default is mock, so we can run on Darwin and Windows without killing those.
var nl netLink = mocNL{}
var nu netUtil = mocNU{}
var db dbusUtil = mocDBUS{}
var fs fsUtil
