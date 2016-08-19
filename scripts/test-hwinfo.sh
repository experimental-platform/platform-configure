#!/usr/bin/env bash

set -eu

get_field() {
	local BODY="$1"
	local PARAM="$2"

	echo "$BODY" | grep --extended-regexp --only-matching "$PARAM: .*" | sed -r "s#$PARAM: ##"
}

JSON='{"network": []}'

# Get motherboard info
JSON="$(jq --arg val "$(</sys/devices/virtual/dmi/id/product_uuid)" '.motherboard.uuid |= $val' <<< "$JSON")"
JSON="$(jq --arg val "$(</sys/devices/virtual/dmi/id/board_serial)" '.motherboard.serial |= $val' <<< "$JSON")"
JSON="$(jq --arg val "$(</sys/devices/virtual/dmi/id/board_name)" '.motherboard.name |= $val' <<< "$JSON")"
JSON="$(jq --arg val "$(</sys/devices/virtual/dmi/id/board_vendor)" '.motherboard.vendor |= $val' <<< "$JSON")"
JSON="$(jq --arg val "$(</sys/devices/virtual/dmi/id/board_version)" '.motherboard.version |= $val' <<< "$JSON")"


# Get RAM info
for i in $(seq 0 15); do
	OUTPUT="$(lshw -C memory | sed -n -e "/*-bank:$i/,/*-/ p")"
	if [ ! -z "$OUTPUT" ]; then
		PRODUCT="$(get_field "$OUTPUT" product)"
		VENDOR="$(get_field "$OUTPUT" vendor)"
		ID="$(get_field "$OUTPUT" 'physical id')"
		SERIAL="$(get_field "$OUTPUT" 'serial')"
		SLOT="$(get_field "$OUTPUT" 'slot')"
		SIZE="$(get_field "$OUTPUT" 'size')"
		STICK="$(jq \
			--arg product "$PRODUCT" \
			--arg vendor "$VENDOR" \
			--arg id "$ID" \
			--arg serial "$SERIAL" \
			--arg slot "$SLOT" \
			--arg size "$SIZE" \
			'.product |= $product | .vendor |= $vendor | .id |= $id | .serial |= $serial | .slot |= $slot | .size |= $size' <<< "{}")"

		JSON="$(jq --argjson stick "$STICK" ".ram[$ID] |= \$stick" <<< "$JSON")"
	fi
done

# Get drive info
JSON="$(jq --argjson val "$(lsblk -J -o NAME,RM,HOTPLUG,ROTA,SIZE,TYPE,MOUNTPOINT,MODEL,VENDOR,SERIAL,FSTYPE,LABEL,PARTLABEL,UUID,PARTUUID)" '.drives |= $val.blockdevices' <<< "$JSON")"

# get bootstick info
if [[ -f /etc/protonet-bootstick ]] && jq '.' /etc/protonet-bootstick &>/dev/null; then
   JSON="$(jq --argjson val "$(cat /etc/protonet-bootstick)" '.bootstick |= $val' <<< "$JSON")"
fi

# get system channel
if skvs_cli get system/channel; then
    JSON="$(jq --arg val "$(skvs_cli get system/channel)" '.channel |= $val' <<< "$JSON")"
fi

# get support identifier
if skvs_cli get support_identifier; then
    JSON="$(jq --arg val "$(skvs_cli get support_identifier)" '.support_identifier |= $val' <<< "$JSON")"
fi


for i in /sys/class/net/*; do
	NAME="$(basename "$i")"
	SPEED="$(cat $i/speed 2>/dev/null || echo null)"
	LABEL="$(cat $i/device/label 2>/dev/null || echo null)"
	IPV4="$(ifconfig "$NAME" | grep -E --only-matching 'inet [0-9\.]+' | sed 's/^inet //')"
	IPV6="$(ifconfig "$NAME" | grep -E --only-matching 'inet6 [0-9a-f\:]+' | sed 's/^inet6 //')"
	if [ -z "$IPV4" ]; then IPV4='null'; fi
	if [ -z "$IPV6" ]; then IPV6='null'; fi
	NIC="$(jq \
		--arg name "$NAME" \
		--arg mac "$(<$i/address)" \
		--argjson carrier "$(<$i/carrier)" \
		--argjson mtu "$(<$i/mtu)" \
		--argjson speed "$SPEED" \
		--arg devlabel "$LABEL" \
		--arg ipv4 "$IPV4" \
		--arg ipv6 "$IPV6" \
		'.name = $name |
		.mac = $mac |
		.carrier = if $carrier == 1 then true else false end |
		.mtu = $mtu |
		.speed = $speed |
		.label = if $devlabel == "null" then null else $devlabel end |
		.ipv4 = if $ipv4 == "null" then null else $ipv4 end |
		.ipv6 = if $ipv6 == "null" then null else $ipv6 end' <<< "{}")"
	JSON="$(jq --argjson nic "$NIC" '.network += [$nic]' <<< "$JSON")"
done

echo "$JSON"
