#!/usr/bin/env bash

set -eu
set -o pipefail

generate_random () {
	dd if=/dev/urandom bs=1k count=1 2>/dev/null | sha256sum -b | cut -f1 -d ' '
}


configure_network () {
    cat > "/etc/systemd/network/gitlab.network" <<EOF
# Created by the Protonet Gitlab Installer -- do not edit this line!
[Match]
Name=engitlab*

[Network]
DHCP=yes

[DHCP]
UseDomains=false
UseRoutes=false
RouteMetric=65000
EOF
    systemctl daemon-reload
    systemctl restart systemd-networkd.service
}


unconfigure_network () {
    if grep "Created by the Protonet Gitlab Installer" "/etc/systemd/network/gitlab.network" &>/dev/null; then
        rm -f "/etc/systemd/network/gitlab.network"
    fi
}


enable_gitlab() {
	local MYSQL_PASSWORD

	# needs to be successfull prior to enabling gitlab (which creates the interface)
	configure_network

	skvs_cli set gitlab/enabled ' '

	if ! skvs_cli get gitlab/mysql_passwd 2>/dev/null; then
		MYSQL_PASSWORD="$(generate_random)"
		skvs_cli set gitlab/mysql_passwd "$MYSQL_PASSWORD"
	else
		MYSQL_PASSWORD="$(skvs_cli get gitlab/mysql_passwd)"
	fi

	if ! skvs_cli get gitlab/secrets_db_key_base 2>/dev/null; then
		skvs_cli set gitlab/secrets_db_key_base "$(generate_random)"
	fi

	if ! skvs_cli get gitlab/secrets_secret_key_base 2>/dev/null; then
		skvs_cli set gitlab/secrets_secret_key_base "$(generate_random)"
	fi

	if ! skvs_cli get gitlab/secrets_otp_key_base 2>/dev/null; then
		skvs_cli set gitlab/secrets_otp_key_base "$(generate_random)"
	fi

	MYSQL_QUERY="CREATE DATABASE IF NOT EXISTS gitlab DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
	CREATE USER IF NOT EXISTS 'gitlab'@'%';
	SET PASSWORD FOR 'gitlab'@'%' = PASSWORD('$MYSQL_PASSWORD');
	GRANT ALL PRIVILEGES ON gitlab.* TO 'gitlab'@'%';"
	docker exec -i mysql mysql --password=s3kr3t --batch <<< "$MYSQL_QUERY"

	systemctl daemon-reload
	systemctl start gitlab
	systemctl enable gitlab
	# Make sure the network ip timer is restarted, even on repeat reinstalls
	systemctl start gitlab-network-ip.timer
}


disable_gitlab() {
	systemctl disable gitlab
	systemctl stop gitlab
	systemctl stop gitlab-redis
	systemctl stop gitlab-network-ip.timer
	skvs_cli delete gitlab
    unconfigure_network
    systemctl daemon-reload
    systemctl restart systemd-networkd.service
#	Let's not drop the data
#	echo "DROP DATABASE IF EXISTS gitlab; DROP USER IF EXISTS 'gitlab'@'%';" | docker exec -i mysql mysql --password=s3kr3t --batch
}

if [ $# -gt 0 ] && [ "$1" == '--disable' ]; then
	disable_gitlab
else
#	generate_random
	enable_gitlab
	echo "The address is: http://$(gitlab-network show)/"
fi
