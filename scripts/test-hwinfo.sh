#!/usr/bin/env bash

set -eu

get_field() {
	local BODY="$1"
	local PARAM="$2"

	echo "$BODY" | grep --extended-regexp --only-matching "$PARAM: .*" | sed -r "s#$PARAM: ##"
}

JSON="{}"

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

echo "$JSON"
