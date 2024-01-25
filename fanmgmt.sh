#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG="$SCRIPT_DIR/fanmgmt.conf"
CONNECTION_STR=""
CRIT_TEMP_FLAG="False"
COLD_TEMP_FLAG="False"
F9="False"
F8="False"
F7="False"
F6="False"
F5="False"
F4="False"
F3="False"
TOOLS="curl smartctl sensors"

source "$CONFIG"

if [[ $AUTHMETHOD == 'key' ]]; then
  CONNECTION_STR="ssh -i $KEY -o KexAlgorithms=diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o PubkeyAcceptedKeyTypes=ssh-rsa $USER@$HOST"
elif [[ $AUTHMETHOD == 'password' ]]; then
  TOOLS+=" sshpass"
  CONNECTION_STR="sshpass -p $PASS ssh -o KexAlgorithms=diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa $USER@$HOST"
else
  echo "Invalid AUTHMETHOD in config. Aborting." >&2
  exit 1
fi

for tool in $TOOLS
do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "${0##*/}: ${tool} is not installed. Aborting." >&2
    exit 1
  fi
done

function send_email() {
  curl --url "smtp://$SMTP_SERVER:$SMTP_PORT" \
       --ssl-reqd \
       --tlsv1.2 \
       --mail-from "$SMTP_USERNAME" \
       --mail-rcpt "$RECIPIENT" \
       --user "$SMTP_USERNAME:$SMTP_PASSWORD" \
       -T <(echo -e "$@1")
}

function unset_flags() {
    CRIT_TEMP_FLAG="False"
    COLD_TEMP_FLAG="False"
    F9="False"
    F8="False"
    F7="False"
    F6="False"
    F5="False"
    F4="False"
    F3="False"
}

CPU_PERC90=$(printf "%.0f" "$(echo "$CPU_CRITICAL_TEMP * 0.9" | bc -l)")
CPU_PERC80=$(printf "%.0f" "$(echo "$CPU_CRITICAL_TEMP * 0.8" | bc -l)")
CPU_PERC70=$(printf "%.0f" "$(echo "$CPU_CRITICAL_TEMP * 0.7" | bc -l)")
CPU_PERC60=$(printf "%.0f" "$(echo "$CPU_CRITICAL_TEMP * 0.6" | bc -l)")
CPU_PERC50=$(printf "%.0f" "$(echo "$CPU_CRITICAL_TEMP * 0.5" | bc -l)")
CPU_PERC40=$(printf "%.0f" "$(echo "$CPU_CRITICAL_TEMP * 0.4" | bc -l)")
CPU_PERC30=$(printf "%.0f" "$(echo "$CPU_CRITICAL_TEMP * 0.2" | bc -l)")
HDD_PERC90=$(printf "%.0f" "$(echo "$HDD_CRITICAL_TEMP * 0.95" | bc -l)")
HDD_PERC80=$(printf "%.0f" "$(echo "$HDD_CRITICAL_TEMP * 0.9" | bc -l)")
HDD_PERC70=$(printf "%.0f" "$(echo "$HDD_CRITICAL_TEMP * 0.85" | bc -l)")
HDD_PERC60=$(printf "%.0f" "$(echo "$HDD_CRITICAL_TEMP * 0.8" | bc -l)")
HDD_PERC50=$(printf "%.0f" "$(echo "$HDD_CRITICAL_TEMP * 0.75" | bc -l)")
HDD_PERC40=$(printf "%.0f" "$(echo "$HDD_CRITICAL_TEMP * 0.7" | bc -l)")
HDD_PERC30=$(printf "%.0f" "$(echo "$HDD_CRITICAL_TEMP * 0.35" | bc -l)")

while true;
do
  HDD2=$(smartctl -a /dev/sdb | grep 194 | grep -Eo '[0-9.]+' | sed '7q;d')
  HDD3=$(smartctl -a /dev/sdc | grep 194 | grep -Eo '[0-9.]+' | sed '7q;d')
  HDD4=$(smartctl -a /dev/sdd | grep 194 | grep -Eo '[0-9.]+' | sed '7q;d')
  CPU0=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 0" | .temp2_input')
  CPU1=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 1" | .temp3_input')
  CPU2=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 2" | .temp4_input')
  CPU3=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 3" | .temp5_input')
  CPUP=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Package id 0" | .temp1_input')

  if [[ $HDD2 -ge $HDD_CRITICAL_TEMP  || $HDD3 -ge $HDD_CRITICAL_TEMP  || $HDD4 -ge $HDD_CRITICAL_TEMP  || $CPU0 -ge $CPU_CRITICAL_TEMP  || $CPU1 -ge $CPU_CRITICAL_TEMP  || $CPU2 -ge $CPU_CRITICAL_TEMP  || $CPU3 -ge $CPU_CRITICAL_TEMP  || $CPUP -ge $CPU_CRITICAL_TEMP ]]; then
    if [[ $CRIT_TEMP_FLAG == "False" ]]; then
      eval "${CONNECTION_STR} 'fan p 0 max 255'"
      eval "${CONNECTION_STR} 'fan p 0 min 240'"
      subject="[HP Server] [ALERT] Server is boiling!"
      body="TEMPERATURES:\n
HDD2: $HDD2\n
HDD3: $HDD3\n
HDD4: $HDD4\n
CPU0: $CPU0\n
CPU1: $CPU1\n
CPU2: $CPU2\n
CPU3: $CPU3\n
CPU Package: $CPUP"
      message="Subject: $subject\n\n$body"
      send_email "$message"
    fi
    if [[ $CRIT_TEMP_FLAG == "True" ]]; then
      subject="[HP Server] [ALERT] Server is shutting down!"
      body="TEMPERATURES:\n
HDD2: $HDD2\n
HDD3: $HDD3\n
HDD4: $HDD4\n
CPU0: $CPU0\n
CPU1: $CPU1\n
CPU2: $CPU2\n
CPU3: $CPU3\n
CPU Package: $CPUP
FLAG: $CRIT_TEMP_FLAG"
      message="Subject: $subject\n\n$body"
      send_email "$message"
      shutdown
    else
      unset_flags
      CRIT_TEMP_FLAG="True"
    fi

  elif [[ $HDD2 -ge $HDD_PERC90  || $HDD3 -ge $HDD_PERC90  || $HDD4 -ge $HDD_PERC90  || $CPU0 -ge $CPU_PERC90  || $CPU1 -ge $CPU_PERC90  || $CPU2 -ge $CPU_PERC90  || $CPU3 -ge $CPU_PERC90  || $CPUP -ge $CPU_PERC90 ]]; then
    if [[ $F9 == "False" ]]; then
      eval "${CONNECTION_STR} 'fan p 0 max 255'"
      eval "${CONNECTION_STR} 'fan p 0 min 208'"
    fi
    unset_flags
    F9="True"

  elif [[ $HDD2 -ge $HDD_PERC80  || $HDD3 -ge $HDD_PERC80  || $HDD4 -ge $HDD_PERC80  || $CPU0 -ge $CPU_PERC80  || $CPU1 -ge $CPU_PERC80  || $CPU2 -ge $CPU_PERC80  || $CPU3 -ge $CPU_PERC80  || $CPUP -ge $CPU_PERC80 ]]; then
    if [[ $F8 == "False" ]]; then
      eval "${CONNECTION_STR} 'fan p 0 max 255'"
      eval "${CONNECTION_STR} 'fan p 0 min 168'"
    fi
    unset_flags
    F8="True"

  elif [[ $HDD2 -ge $HDD_PERC70  || $HDD3 -ge $HDD_PERC70  || $HDD4 -ge $HDD_PERC70  || $CPU0 -ge $CPU_PERC70  || $CPU1 -ge $CPU_PERC70  || $CPU2 -ge $CPU_PERC70  || $CPU3 -ge $CPU_PERC70  || $CPUP -ge $CPU_PERC70 ]]; then
    if [[ $F7 == "False" ]]; then
      eval "${CONNECTION_STR} 'fan p 0 max 255'"
      eval "${CONNECTION_STR} 'fan p 0 min 128'"
    fi
    unset_flags
    F7="True"

  elif [[ $HDD2 -ge $HDD_PERC60  || $HDD3 -ge $HDD_PERC60  || $HDD4 -ge $HDD_PERC60  || $CPU0 -ge $CPU_PERC60  || $CPU1 -ge $CPU_PERC60  || $CPU2 -ge $CPU_PERC60  || $CPU3 -ge $CPU_PERC60  || $CPUP -ge $CPU_PERC60 ]]; then
    if [[ $F6 == "False" ]]; then
      eval "${CONNECTION_STR} 'fan p 0 max 255'"
      eval "${CONNECTION_STR} 'fan p 0 min 96'"
    fi
    unset_flags
    F6="True"

  elif [[ $HDD2 -ge $HDD_PERC50  || $HDD3 -ge $HDD_PERC50  || $HDD4 -ge $HDD_PERC50  || $CPU0 -ge $CPU_PERC50  || $CPU1 -ge $CPU_PERC50  || $CPU2 -ge $CPU_PERC50  || $CPU3 -ge $CPU_PERC50  || $CPUP -ge $CPU_PERC50 ]]; then
    if [[ $F5 == "False" ]]; then
      eval "${CONNECTION_STR} 'fan p 0 max 255'"
      eval "${CONNECTION_STR} 'fan p 0 min 64'"
    fi
    unset_flags
    F5="True"

  elif [[ $HDD2 -ge $HDD_PERC40  || $HDD3 -ge $HDD_PERC40  || $HDD4 -ge $HDD_PERC40  || $CPU0 -ge $CPU_PERC40  || $CPU1 -ge $CPU_PERC40  || $CPU2 -ge $CPU_PERC40  || $CPU3 -ge $CPU_PERC40  || $CPUP -ge $CPU_PERC40 ]]; then
    if [[ $F4 == "False" ]]; then
      eval "${CONNECTION_STR} 'fan p 0 max 255'"
      eval "${CONNECTION_STR} 'fan p 0 min 40'"
    fi
    unset_flags
    F4="True"

  elif [[ $HDD2 -gt $HDD_PERC30  || $HDD3 -gt $HDD_PERC30  || $HDD4 -gt $HDD_PERC30  || $CPU0 -gt $CPU_PERC30  || $CPU1 -gt $CPU_PERC30  || $CPU2 -gt $CPU_PERC30  || $CPU3 -gt $CPU_PERC30  || $CPUP -gt $CPU_PERC30 ]]; then
    if [[ $F3 == "False" ]]; then
      eval "${CONNECTION_STR} 'fan p 0 max 255'"
      eval "${CONNECTION_STR} 'fan p 0 min 16'"
    fi
    unset_flags
    F3="True"

  else
    if [[ $COLD_TEMP_FLAG == "False" ]]; then
      eval "${CONNECTION_STR} 'fan p 0 max 1'"
      eval "${CONNECTION_STR} 'fan p 0 min 0'"
      unset_flags
      COLD_TEMP_FLAG="True"
      subject="[HP Server] [ALERT] Server is freezing!"
      body="TEMPERATURES:\n
HDD2: $HDD2\n
HDD3: $HDD3\n
HDD4: $HDD4\n
CPU0: $CPU0\n
CPU1: $CPU1\n
CPU2: $CPU2\n
CPU3: $CPU3\n
CPU Package: $CPUP"
      message="Subject: $subject\n\n$body"
      send_email "$message"
    fi
  fi
  sleep "$FREQ"
done
