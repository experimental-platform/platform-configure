#!/usr/bin/env bash

set -eu

EXIT_CODE=0
ERROR="\x1b[93;41mERROR\x1b[0m"
JSON={}
JSON_OUTPUT=false

while [[ $# > 0 ]]; do
  key="$1"
  case $key in
    --json)
      JSON_OUTPUT=true
    ;;
    *)
      echo "Unknown parameter '$key'"
      exit 1
    ;;
  esac
  shift
done

test_soul() {
    # SOUL_URL=http://172.17.0.1 # Note: We should set this automatically to DOCKERHOST ip
    SOUL_USERNAME=${SOUL_USERNAME:="admin.admin"}
    SOUL_PASSWORD=${SOUL_PASSWORD:="Changeme!123"}
    SOUL_GROUP_NAME=${SOUL_GROUP_NAME:="CHANGEME"}
    SOUL_HOSTNAME=${SOUL_HOSTNAME:-} # Note: This is one is an optional parameter, and is newly added. Needed for connecting via IP
    SOUL_URL=${SOUL_URL:="http://10.42.0.1"}
    SOUL_SSH_PASSWORD=${SOUL_SSH_PASSWORD:-}
    if [[ -z ${SOUL_SSH_PASSWORD} ]]; then
        if [[ -f "/etc/protonet/system/ssh/password" ]]; then
            # if masterpassword was used
            SOUL_SSH_PASSWORD=$(cat "/etc/protonet/system/ssh/password")
        else
            # default installation password - gets disabled on setup
            SOUL_SSH_PASSWORD="1nsta!lMe"
        fi
    fi

    if docker pull quay.io/experimentalplatform/soul-integration &>/dev/null; then
        docker run -ti --rm \
            -e "SOUL_USERNAME=${SOUL_USERNAME}" \
            -e "SOUL_PASSWORD=${SOUL_PASSWORD}" \
            -e "SOUL_GROUP_NAME=${SOUL_GROUP_NAME}" \
            -e "SOUL_HOSTNAME=${SOUL_HOSTNAME}" \
            -e "SOUL_URL=${SOUL_URL}" \
            -e "SOUL_SSH_PASSWORD=${SOUL_SSH_PASSWORD}" \
            quay.io/experimentalplatform/soul-integration bundle exec rspec --tag readonly
    else
        echo "ERROR DOWNLOADING THE SOUL INTEGRATION TESTS."
    fi
}


run_tests() {
    # TODO: add test_soul
    for testname in test-disks test-ipmi-disabled test-ipmi-sdr test-software-overview test-stress; do
        if [[ -x "/etc/systemd/system/scripts/${testname}.sh" ]]; then
            OUTFILE=$(mktemp)
            /etc/systemd/system/scripts/${testname}.sh > "$OUTFILE" | true
            STATUS=${PIPESTATUS[0]}
            OUTPUT="$(<$OUTFILE)"
            [ "$JSON_OUTPUT" != "true" ] && echo "$OUTPUT"
            if [ $STATUS -eq 0 ]; then
              STATUS="ok"
            else
              STATUS="failed"
              EXIT_CODE=23
              [ "$JSON_OUTPUT" != "true" ] && echo -e "\n\n"
            fi

            JSON="$(jq --arg testname "$testname" --arg status "$STATUS" --arg output "$OUTPUT" '.tests[$testname].status = $status | .tests[$testname].output = $output' <<< "$JSON")"
        else
            [ "$JSON_OUTPUT" != "true" ] && echo -e "${ERROR}: Test \"${testname}\" not found!"
            EXIT_CODE=23
            JSON="$(jq --arg testname "$testname" '.tests.status[$testname] = "not-found"' <<< "$JSON")"
        fi
    done
}


trap "button error >/dev/null 2>&1 || true" SIGINT SIGTERM EXIT
button rainbow || true
run_tests
trap - SIGINT SIGTERM EXIT


HWINFO=$(sudo /etc/systemd/system/scripts/test-hwinfo.sh)
if [ "$JSON_OUTPUT" != "true" ]; then
  echo -e "HARDWARE INFO\n"
  echo -e "MAINBOARD:"
  jq ' .motherboard | "Vendor: \(.vendor)    Name: \(.name)    Version: \(.version)    Serial: \(.serial)"' --raw-output <<< ${HWINFO}
  echo -e "\nRAM:"
  jq ' .ram | map("Vendor: \(.vendor)    Slot: \(.slot)    Size: \(.size)    Product: \(.product)    Serial: \(.serial)")' --raw-output <<< ${HWINFO}
  echo -e "\nHARD DISKS (and USB Sticks):"
  jq ' .drives | map("Vendor: \(.vendor)    Model: \(.model)    Size: \(.size)    Serial: \(.serial)")' --raw-output <<< ${HWINFO}
  echo -e "\nMAC ADDRESSES:"
  jq '.network | map(select(.name | startswith("veth") | not) | select(.name != "docker0") | select(.name != "lo") | select(.name | startswith("br-") | not) | "\(.name): \(.mac)")[]' --raw-output <<< ${HWINFO}

  echo -e "\nSOFTWARE CHANNEL, BOOT STICK BUILD AND SUPPORT IDENTIFIER:"
  jq ' "SYSTEM CHANNEL: \(.channel)"' --raw-output <<< ${HWINFO}
  jq ' "BOOTSTICK CHANNEL: \(.bootstick.BRANCH)"' --raw-output <<< ${HWINFO}
  jq ' "BOOTSTICK BUILD: \(.bootstick.BUILD)"' --raw-output <<< ${HWINFO}
  jq ' "SUPPORT IDENTIFIER: \(.support_identifier)"' --raw-output <<< ${HWINFO}
fi

JSON="$(jq --argjson hwinfo "$HWINFO" '.hwinfo = $hwinfo' <<< "$JSON")"

if [[ "${EXIT_CODE}" -eq "0" ]]; then
    button hdd || true
    [ "$JSON_OUTPUT" != "true" ] && echo -e "\n\nOKAY -- OKAY -- OKAY\nALL TESTS SUCCESSFUL\n"
else
    button error || true
    [ "$JSON_OUTPUT" != "true" ] && echo -e "\n\n${ERROR}: A TEST WENT WRONG, PLEASE INVESTIGATE"
fi

if [ "$JSON_OUTPUT" == "true" ]; then
  echo "$JSON"
fi

