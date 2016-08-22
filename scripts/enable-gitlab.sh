#!/usr/bin/env bash

set -eu
set -o pipefail

generate_random () {
	dd if=/dev/urandom bs=1k count=1 2>/dev/null | sha256sum -b | cut -f1 -d ' '
}

enable_gitlab() {
	local MYSQL_PASSWORD

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
	skvs_cli delete gitlab
	systemctl daemon-reload
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
