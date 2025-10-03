#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source ${SCRIPT_DIR}/qnap_config.sh
service=99
device=remote-cli
force_to_check_2sv=0
remme=1
hostname=$(hostname)

SID_CACHE_FILENAME=".authcache"
SID_CACHE_ABS_PATH="${SCRIPT_DIR}/${SID_CACHE_FILENAME}"
SID_CACHE_MAX_FILE_AGE_SEC=300

RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

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

vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

CONCAT(){
    echo "$1$2"
}

CONV_TO_JSON_NEW(){
    while IFS= read -r line ; do
        echo $line;
    done <<< "$1"
}

CONV_TO_JSON(){
    i=0
    final_json="{"

    str_in=$1
    str_in="${str_in}
    hostname=${hostname}
    source=${hostname}
    tag=qnap_api
    "
    
    while IFS= read -r line ; do
        line_trimmed=$(echo "$line")
        line_key=$(echo $line_trimmed | cut -d '=' -f 1)
        line_value=$(echo $line_trimmed | cut -d '=' -f 2)

        if [[ ! -z $line_key ]]; then
            if [[ ! -z $line_value ]]; then
                if (( i > 0 )); then
                    final_json=$(CONCAT "$final_json" ", ")
                fi
                final_json=$(CONCAT "$final_json" \""$line_key"\")
                final_json=$(CONCAT "$final_json" ":")
                final_json=$(CONCAT "$final_json" \""$line_value"\")
                i=$((i+1))
            fi
        fi

    done <<< "$str_in"
    
    final_json=$(CONCAT "$final_json" "}")

    echo $final_json
}

send_gelf_payload(){
    payload=$(CONV_TO_JSON "$1")
    
    echo "$payload"

    curl --location "$GELF_URI" \
        --header 'Content-Type: application/json' \
        --silent \
        --data-raw "$payload"
}

ERROR_CONTROL() {
    if (( $1 > 0 )); then
        echo "NON ZERO EXIT CODE: ${1}"
        # exit
    fi
}

EXIT_ON_TOKEN_EMPTY() {
    if [[ -z $1 ]]; then
        echo "ERROR, Token Empty"
        exit 1
    fi
}

EXIT_ON_WHICH_EMPTY() {
    (which $1)
    exit_code=$?
    if (( $exit_code > 0 )); then
        echo "ERROR: cannot find ${1}"
        exit
    fi
}

GET_UNIX_EPOCH_OF_FILE() {
    absfile=$1
    isodate=$(ls -al --time-style=full-iso ${absfile} | sed -E 's/^.* ([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]+).[0-9]+ .*$/\1/')
    unixdate=$(date -d "$isodate" +"%s")
    echo $unixdate
}

GET_UNIX_EPOCH_NOW() {
    echo $(date +"%s")
}

GET_FILE_DIFF_SEC() {
    d1=$1
    d2=$2
    echo $(( d1 - d2 ))
}

query_qnap(){
    ARG_COMMAND=$1
    case ${ARG_COMMAND} in
        auth)
            /usr/bin/curl --silent \
                $CMD_ARG_TO_VERIFY_CURL_URL \
                -XPOST \
                --location "${base_qnap_host}/cgi-bin/authLogin.cgi?user=${username}&plain_pwd=${pwd_in_plain_text}&remme=${remme}&service=${service}&device=${device}&force_to_check_2sv=${force_to_check_2sv}" \
                | grep -oP '\<authSid\>.*?\<\/authSid\>' | grep -oP 'CDATA\[(.*?)\]' | grep -oP '\[.*\]' | grep -oP '[^\[\]]+'
            ;;
        auth_w_cache)
            continue=1

            if [ -f "${SID_CACHE_ABS_PATH}" ]; then
                unix_now=$(GET_UNIX_EPOCH_NOW)
                file_epoch=$(GET_UNIX_EPOCH_OF_FILE ${SID_CACHE_ABS_PATH})
                diff=$(GET_FILE_DIFF_SEC ${unix_now} ${file_epoch})
                if (( $diff > $SID_CACHE_MAX_FILE_AGE_SEC )); then
                    # removing outdated cache file
                    rm -f "${SID_CACHE_ABS_PATH}" >/dev/null 2>&1
                else
                    # test?
                    TOKEN=$(cat "${SID_CACHE_ABS_PATH}")
                    AUTH_PASSED=$(query_qnap verify_auth "${TOKEN}")

                    if [[ "$authpassed" == "1" ]]; then
                        # verified token is good, we can return it
                        echo "${TOKEN}"
                        continue=0
                    fi
                fi
            fi

            if [ $continue -gt 0 ]; then
                TOKEN=$(query_qnap auth)

                # if file missing, create and set permission
                if [ ! -f "${SID_CACHE_ABS_PATH}" ]; then
                    touch "${SID_CACHE_ABS_PATH}" >/dev/null 2>&1
                    chmod 600 "${SID_CACHE_ABS_PATH}" >/dev/null 2>&1
                fi

                if [ -f "${SID_CACHE_ABS_PATH}" ]; then
                    echo ${TOKEN} > "${SID_CACHE_ABS_PATH}"
                fi

                echo ${TOKEN}
            fi
            ;;
        verify_auth)
            USE_FOR_TOKEN=$2
            authpassed=0
            authpassed=$(/usr/bin/curl --fail --silent $CMD_ARG_TO_VERIFY_CURL_URL --location "${base_qnap_host}/cgi-bin/sysinfoReq.cgi?sid=${USE_FOR_TOKEN}"| grep -oPi "<authpassed>.*?</authPassed>" | sed -E 's#<authPassed><!\[CDATA\[(.*)\]\]></authPassed>#\1#')
            if [[ "$authpassed" != "1" ]]; then
                authpassed=0
            fi
            echo $authpassed
            ;;
        status)
            TOKEN=$(query_qnap auth_w_cache)
            EXIT_ON_TOKEN_EMPTY $TOKEN
            
            /usr/bin/curl \
                --silent \
                --fail \
                $CMD_ARG_TO_VERIFY_CURL_URL \
                -XPOST \
                --location "${base_qnap_host}/cgi-bin/net/networkRequest.cgi?sid=${TOKEN}&subfunc=snmp" | grep -io \<snmp_enable\>.*\<\/snmp_enable\> | grep -io cdata\\[[[:digit:]]\\] | grep -io \\[[[:digit:]]\\] | grep -oP '0|1'
            ;;
        disable)
            TOKEN=$(query_qnap auth)
            /usr/bin/curl --location "${base_qnap_host}/cgi-bin/net/networkRequest.cgi?sid=${TOKEN}&subfunc=snmp&apply=1" \
                -v \
                $CMD_ARG_TO_VERIFY_CURL_URL \
                --header 'Content-Type: text/plain' \
                --data 'event_count=123&snmp_auth_protocol=0&select_snmp_version=v1&chkValue=0' \
                 > /dev/null 2>&1
            ;;
        enable)
            TOKEN=$(query_qnap auth)
            /usr/bin/curl --location "${base_qnap_host}/cgi-bin/net/networkRequest.cgi?sid=${TOKEN}&subfunc=snmp&apply=1" \
                -v \
                $CMD_ARG_TO_VERIFY_CURL_URL \
                --header 'Content-Type: text/plain' \
                --data 'chk_snmp=on&snmp_port=161&snmp_community=public&event_count=123&snmp_auth_protocol=0&select_snmp_version=v1&chkValue=0' \
                 > /dev/null 2>&1
            ;;
    esac
}

PARSE_VERIFY_CURL_URL() {
    Y_OR_N=$(to_lowercase ${1})
    case ${Y_OR_N} in
        y)
            echo ""
            ;;
        n)
            echo "-k"
            ;;
    esac
}

escape_quotes() {
  local input="$1"
  echo "$input" | sed 's/"/\\"/g'
}

CMD_ARG_TO_VERIFY_CURL_URL=$(PARSE_VERIFY_CURL_URL $VERIFY_CERT)

# verify HTTPS trust
/usr/bin/curl --silent $CMD_ARG_TO_VERIFY_CURL_URL ${base_qnap_host} > /dev/null 2>&1
curl_exit_code=$?
if (( $curl_exit_code > 0 )); then
    echo "Failed to connect to URL: ${base_qnap_host}"
    echo "NON ZERO EXIT CODE: $curl_exit_code"
    /usr/bin/curl -v $CMD_ARG_TO_VERIFY_CURL_URL ${base_qnap_host}
    exit
fi

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
    firmware)
        TOKEN=$(query_qnap auth)
        FIRMWARECHECK=$(/usr/bin/curl --silent --request POST --location "${base_qnap_host}/cgi-bin/sys/sysRequest.cgi?sid=${TOKEN}" --data 'subfunc=firm_update&liveupdate=1&beta=1&ver=3&skip_deployment=1&check_online_version=2')

        FW_CUR_P=$(echo $FIRMWARECHECK | grep -oP '<firmware>.*</firmware>')
        FW_CUR_P_VER=$(echo $FW_CUR_P | grep -oP '<version>.*</version>' | sed -n 's/.*<!\[CDATA\[\(.*\)\]\]>.*$/\1/p')
        FW_CUR_P_NUM=$(echo $FW_CUR_P | grep -oP '<number>.*</number>' | sed -n 's/.*<!\[CDATA\[\(.*\)\]\]>.*$/\1/p')
        FW_CUR_VER=$(echo "${FW_CUR_P_VER}.${FW_CUR_P_NUM}")

        FW_NEW_P=$(echo $FIRMWARECHECK | grep -oP '<newVersion>.*</newVersion>')
        FW_NEW_VER=$(echo $FW_NEW_P | sed -n 's/.*<!\[CDATA\[\([[:digit:]\.]\+\).*\]\]>.*$/\1/p')
        # FW_NEW_VER="5.3"

        if [[ -z $FW_NEW_VER ]]; then
            FW_NEW_VER=$FW_CUR_VER
        fi

        echo "Current: ${FW_CUR_VER}, New: ${FW_NEW_VER}"

        vercomp $FW_NEW_VER $FW_CUR_VER
        # 0 : A = B
        # 1 : A > B
        # 2 : B > A
        if [ $? -eq 0 ]; then
            echo "No firmware update"

            JSON_PREP="message=NO Firmware update available.
            qnap_cur_ver=${FW_CUR_VER}
            "
            send_gelf_payload "$JSON_PREP"
        elif [ $? -eq 1 ]; then
            echo "New Firmware Available: ${FW_NEW_VER}"
            
            JSON_PREP="message=New Firmware Available for QNAP
            qnap_cur_ver=${FW_CUR_VER}
            qnap_new_ver=${FW_NEW_VER}
            "
            send_gelf_payload "$JSON_PREP"
        elif [ $? -eq 2 ]; then
            echo "Existing firmware is newer than latest update. This should NEVER happen"
        fi
        ;;
    cs_status)
        TOKEN=$(query_qnap auth)
        CS_STATUS=$(/usr/bin/curl --silent --request GET --location "${base_qnap_host}/container-station/api/v3/overview" -H "authorization: Bearer ${TOKEN}")
        echo "Container Station Status: ${CS_STATUS}"
        EXIT_ON_WHICH_EMPTY "jq"
        JQLINES=$(echo "${CS_STATUS}" | jq .data.container | jq -c 'map(.)[]')
        # echo $JQLINES
        while IFS= read -r line ; do
            line_trimmed=$(echo "$line")
            line_escaped=$(escape_quotes $line_trimmed)
            # echo ""
            # echo $line_trimmed
            JSON_PREP="message=QNAP Container Station Container Status
            qnap_cs_status=${line_escaped}
            "
            send_gelf_payload "$JSON_PREP"

        done <<< "$JQLINES"
        ;;
esac
