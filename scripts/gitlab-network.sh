#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

NEW_INTERFACE="engitlab0"


get_interface() {
    ip route get 8.8.8.8 | grep -Po "(?<=dev )e[nt]+[0-9a-z_]+"
}


create_mac() {
    echo "00:11:22:"$(((RANDOM % 10)))$(((RANDOM % 10)))":"$(((RANDOM % 10)))$(((RANDOM % 10)))":"$(((RANDOM % 10)))$(((RANDOM % 10)))
}

get_mac() {
    if [ -f /etc/protonet/gitlab/mac ]; then
        cat /etc/protonet/gitlab/mac
    else
        mkdir -p /etc/protonet/gitlab
        local MAC=$(create_mac)
        echo -n "$MAC" > /etc/protonet/gitlab/mac
        echo -n "$MAC"
    fi
}

create_interface() {
    local INTERFACE MAC
    MAC=$(get_mac)
    INTERFACE=$(get_interface)
    if ! ip link show ${NEW_INTERFACE} &>/dev/null; then
        # ip link set ${INTERFACE} up
        awk " BEGIN { printf \"Creating interface ${NEW_INTERFACE}... \" > \"/dev/fd/2\" }"
        ip link add link ${INTERFACE} address ${MAC} ${NEW_INTERFACE} type macvlan
        awk " BEGIN { print \"DONE\" > \"/dev/fd/2\" }"
    else
        awk " BEGIN { print \"Interface not found ${NEW_INTERFACE}\" > \"/dev/fd/2\" }"
    fi
}


destroy_interface() {
    if ip link show ${NEW_INTERFACE} &>/dev/null; then
        awk " BEGIN { printf \"Shutting down ${NEW_INTERFACE}... \" > \"/dev/fd/2\" }"
        ip link set ${NEW_INTERFACE} down
        ip link delete ${NEW_INTERFACE} type macvlan
        awk " BEGIN { print \"DONE\" > \"/dev/fd/2\" }"
    fi
}


get_ip_adress() {
    if ip link show ${NEW_INTERFACE} &>/dev/null; then
        ip addr show ${NEW_INTERFACE} | awk '/inet\s+/ { gsub("\\/[0-9]+", "", $2); printf $2 }'
    else
        awk " BEGIN { print \"Interface not found ${NEW_INTERFACE}\" > \"/dev/fd/2\" }"
        exit 1
    fi
}


print_usage() {
    echo "$0 start|stop|show"
    echo -e "\tstart:\tcreate the gitlab interface if it does not yet exist."
    echo -e "\tstop:\tdestroy the gitlab interface if it does exist."
    echo -e "\tshow:\tshow the ipv4 address if the interface has one."
}


function parse_options() {
    while [[ $# > 0 ]]; do
        key="$1"
        case $key in
            create|start)
                create_interface
            ;;
            destroy|stop)
                destroy_interface
            ;;
            show)
                get_ip_adress
            ;;
            help)
                print_usage
            ;;
        esac
            shift # past argument or value
    done
}

parse_options "$@"