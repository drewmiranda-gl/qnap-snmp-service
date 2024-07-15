#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source ${SCRIPT_DIR}/qnap_snmp_config.sh
service=99
device=remote-cli
force_to_check_2sv=0
remme=1

to_lowercase(){
    echo $(echo ${1} | awk '{print tolower($1)}')
}

translate_service_status(){
    ARG_RAW_STATUS=$1
    case ${ARG_RAW_STATUS} in
        0)
            echo "stopped/disabled"
            ;;
        1)
            echo "started/enabled"
            ;;
    esac
}

query_qnap(){
    ARG_COMMAND=$1
    case ${ARG_COMMAND} in
        auth)
            curl --silent --cookie-jar cookie.txt -XPOST "${base_qnap_host}/cgi-bin/authLogin.cgi?user=${username}&plain_pwd=${pwd_in_plain_text}&remme=${remme}&service=${service}&device=${device}&force_to_check_2sv={force_to_check_2sv}" > /dev/null 2>&1
            ;;
        status)
            query_qnap auth
            curl --silent --cookie-jar cookie.txt -XPOST "${base_qnap_host}/cgi-bin/net/networkRequest.cgi?sid=s61i8lsk&subfunc=snmp" | grep -io \<snmp_enable\>.*\<\/snmp_enable\> | grep -io cdata\\[[[:digit:]]\\] | grep -io \\[[[:digit:]]\\] | grep -oP '0|1'
            ;;
        disable)
            query_qnap auth
            curl --location "${base_qnap_host}/cgi-bin/net/networkRequest.cgi?sid=s61i8lsk&subfunc=snmp&apply=1" \
                -v \
                --cookie-jar \
                --header 'Content-Type: text/plain' \
                --data 'event_count=123&snmp_auth_protocol=0&select_snmp_version=v1&chkValue=0' \
                 > /dev/null 2>&1
            ;;
        enable)
            query_qnap auth
            curl --location "${base_qnap_host}/cgi-bin/net/networkRequest.cgi?sid=s61i8lsk&subfunc=snmp&apply=1" \
                -v \
                --cookie-jar \
                --header 'Content-Type: text/plain' \
                --data 'chk_snmp=on&snmp_port=161&snmp_community=public&event_count=123&snmp_auth_protocol=0&select_snmp_version=v1&chkValue=0' \
                 > /dev/null 2>&1
            ;;
    esac
}

COMMAND=$1
echo "Command: ${COMMAND}"

case $(to_lowercase ${COMMAND}) in
    status)
        echo "checking SNMP service status..."
        SNMP_STATUS=$(query_qnap status)
        echo "Status: ${SNMP_STATUS} ($(translate_service_status ${SNMP_STATUS}))"
        ;;
    disable|stop)
        SNMP_STATUS=$(query_qnap status)
        echo "Current Status: ${SNMP_STATUS} ($(translate_service_status ${SNMP_STATUS}))"

        echo "disabling SNMP service..."
        query_qnap disable
        
        SNMP_STATUS=$(query_qnap status)
        echo "Status: ${SNMP_STATUS} ($(translate_service_status ${SNMP_STATUS}))"
        ;;
    enable|start)
        SNMP_STATUS=$(query_qnap status)
        echo "Current Status: ${SNMP_STATUS} ($(translate_service_status ${SNMP_STATUS}))"

        echo "enabling SNMP service..."
        query_qnap enable

        SNMP_STATUS=$(query_qnap status)
        echo "Status: ${SNMP_STATUS} ($(translate_service_status ${SNMP_STATUS}))"
        ;;
    restart)
        SNMP_STATUS=$(query_qnap status)
        echo "Current Status: ${SNMP_STATUS} ($(translate_service_status ${SNMP_STATUS}))"

        echo "disabling SNMP service..."
        query_qnap disable

        SNMP_STATUS=$(query_qnap status)
        echo "Status: ${SNMP_STATUS} ($(translate_service_status ${SNMP_STATUS}))"

        echo "enabling SNMP service..."
        query_qnap enable

        SNMP_STATUS=$(query_qnap status)
        echo "Status: ${SNMP_STATUS} ($(translate_service_status ${SNMP_STATUS}))"
        ;;
esac
