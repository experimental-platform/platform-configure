package main

import (
	"fmt"
	"io"

	"github.com/coreos/go-systemd/unit"
)

func generateRedisUnitSerialized(appName string) io.Reader {
	var opts []*unit.UnitOption

	// [Unit]
	opts = append(opts, unit.NewUnitOption("Unit", "Description", fmt.Sprintf("Run redis for %s application", appName)))
	opts = append(opts, unit.NewUnitOption("Unit", "After", "init-protonet.service"))
	opts = append(opts, unit.NewUnitOption("Unit", "Requires", "init-protonet.service"))

	// [Service]
	opts = append(opts, unit.NewUnitOption("Service", "TimeoutStartSec", "0"))
	opts = append(opts, unit.NewUnitOption("Service", "TimeoutStopSec", "15"))
	opts = append(opts, unit.NewUnitOption("Service", "Restart", "always"))
	opts = append(opts, unit.NewUnitOption("Service", "RestartSec", "5s"))
	opts = append(opts, unit.NewUnitOption("Service", "ExecStartPre", fmt.Sprintf("/usr/bin/mkdir -p /data/app/%s/_redis", appName)))
	opts = append(opts, unit.NewUnitOption("Service", "ExecStartPre", fmt.Sprintf("-/usr/bin/docker rm -f app-%s-redis", appName)))
	opts = append(opts, unit.NewUnitOption("Service", "ExecStartPre",
		fmt.Sprintf(`/usr/bin/docker run -d \
		--volume=/data/app/%s/_redis:/data \
		--name=app-%s-redis \
		--net=protonet \
		quay.io/experimentalplatform/redis:development redis-server --appendonly yes`, appName, appName)))
	opts = append(opts, unit.NewUnitOption("Service", "ExecStart", fmt.Sprintf("/usr/bin/docker logs -f app-%s-redis", appName)))
	opts = append(opts, unit.NewUnitOption("Service", "ExecStop", fmt.Sprintf("/usr/bin/docker stop app-%s-redis", appName)))
	opts = append(opts, unit.NewUnitOption("Service", "ExecStopPost", fmt.Sprintf("/usr/bin/docker stop app-%s-redis", appName)))

	// [Install]
	opts = append(opts, unit.NewUnitOption("Install", "WantedBy", "multi-user.target"))

	return unit.Serialize(opts)
}
