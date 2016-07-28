#!/usr/bin/env bash

set -eu
set -o pipefail

generate_random () {
	dd if=/dev/urandom bs=1k count=1 2>/dev/null | sha256sum -b | cut -f1 -d ' '
}

enable_gitlab() {
	local MYSQL_PASSWORD

	mkdir -p /etc/protonet/gitlab
	touch /etc/protonet/gitlab/enabled

	if [ -f /etc/protonet/gitlab/mysql_passwd ]; then
		MYSQL_PASSWORD=$(</etc/protonet/gitlab/mysql_passwd)
	else
		MYSQL_PASSWORD="$(generate_random)"
		echo -n $MYSQL_PASSWORD > /etc/protonet/gitlab/mysql_passwd
	fi

	if [ ! -f /etc/protonet/gitlab/secrets_db_key_base ]; then
		generate_random > /etc/protonet/gitlab/secrets_db_key_base
        fi

	MYSQL_QUERY="CREATE DATABASE IF NOT EXISTS gitlab;
	CREATE USER IF NOT EXISTS 'gitlab'@'%';
	SET PASSWORD FOR 'gitlab'@'%' = PASSWORD('$MYSQL_PASSWORD');
	GRANT ALL PRIVILEGES ON gitlab.* TO 'gitlab'@'%';"
	docker exec -i mysql mysql --password=s3kr3t --batch <<< "$MYSQL_QUERY"

	systemctl daemon-reload
	systemctl start gitlab
	systemctl enable gitlab
}

disable_gitlab() {
	systemctl disable gitlab
	systemctl stop gitlab
	systemctl stop gitlab-redis
	rm -rf /etc/protonet/gitlab
	systemctl daemon-reload
#	Let's not drop the data
#	echo "DROP DATABASE IF EXISTS gitlab; DROP USER IF EXISTS 'gitlab'@'%';" | docker exec -i mysql mysql --password=s3kr3t --batch
}

if [ $# -gt 0 ] && [ "$1" == '--disable' ]; then
	disable_gitlab
else
#	generate_random
	enable_gitlab
fi
