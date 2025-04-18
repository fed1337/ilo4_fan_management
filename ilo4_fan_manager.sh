#!/bin/bash

KEY="$HOME/.ssh/id_rsa"
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
TOOLS="curl smartctl sensors bc jq"

if [ "$EUID" -ne 0 ]; then
  echo "ILO4 Fan manager must run as root!" >&2
  exit 1
fi

load_config() {
  if [[ ! -f "/etc/ilo4_fan_manager.conf" ]]; then
    logger -t ilo4_fan_manager -p user.err "Config not found at /etc/ilo4_fan_manager.conf"
    exit 1
  else
    source "/etc/ilo4_fan_manager.conf"
    logger -t ilo4_fan_manager -p user.info "Config (re)loaded"
  fi
}

load_config

trap 'load_config' SIGHUP

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

if [[ $AUTHMETHOD == 'key' ]]; then
  CONNECTION_STR="ssh -i $KEY -o KexAlgorithms=diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o PubkeyAcceptedKeyTypes=ssh-rsa $USER@$HOST"
elif [[ $AUTHMETHOD == 'password' ]]; then
  TOOLS+=" sshpass"
  CONNECTION_STR="sshpass -p $SSH_PASSWORD ssh -o KexAlgorithms=diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa $USER@$HOST"
else
  logger -t ilo4_fan_manager -p user.err "Invalid AUTHMETHOD in config. Aborting."
  exit 1
fi

for tool in $TOOLS; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    logger -t ilo4_fan_manager -p user.err "${tool} is not installed. Aborting."
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
    -T <(echo -e "$@")
  ret=$?
  if [[ $ret == 0 ]]; then
    logger -t ilo4_fan_manager -p user.notice "Email sent"
  else
    logger -t ilo4_fan_manager -p user.warning "Email is not sent"
  fi
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
  logger -t ilo4_fan_manager -p user.debug "Flags unset"
}

function set_fanspeed() {
  ssh_failed="False"
  eval "${CONNECTION_STR} 'fan p 0 max $1'" >/dev/null 2>&1 || ssh_failed="True"
  eval "${CONNECTION_STR} 'fan p 0 min $2'" >/dev/null 2>&1 || ssh_failed="True"
  if [[ $ssh_failed == "False" ]]; then
    logger -t ilo4_fan_manager -p user.info "Fan speed changed to (max,min): $1,$2"
  else
    subject="[HP Server] [ALERT] Cannot connect to ILO!"
    body="Cannot connect to ILO host: $HOST\n
TEMPERATURES:
SSD: $HDD1
HDD2: $HDD2
HDD3: $HDD3
HDD4: $HDD4
CPU0: $CPU0
CPU1: $CPU1
CPU2: $CPU2
CPU3: $CPU3
CPU Package: $CPUP"
    message="Subject: $subject\n\n$body"
    logger -t ilo4_fan_manager -p user.warning "Cannot connect to ILO ($HOST)"
    send_email "$message"
    return 1
  fi
}

while true; do
  HDD1=$(smartctl -A /dev/disk/by-id/"$HDD1_ID" | grep "194 Temperature_Celsius" | grep -Eo '[0-9.]+' | sed '7q;d')
  HDD2=$(smartctl -A /dev/disk/by-id/"$HDD2_ID" | grep "194 Temperature_Celsius" | grep -Eo '[0-9.]+' | sed '7q;d')
  HDD3=$(smartctl -A /dev/disk/by-id/"$HDD3_ID" | grep "194 Temperature_Celsius" | grep -Eo '[0-9.]+' | sed '7q;d')
  HDD4=$(smartctl -A /dev/disk/by-id/"$HDD4_ID" | grep "194 Temperature_Celsius" | grep -Eo '[0-9.]+' | sed '7q;d')
  # Change sensors name in case these are different for your CPU
  # these can be obtained with command: sensors
  CPU0=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 0" | .temp2_input')
  CPU1=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 1" | .temp3_input')
  CPU2=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 2" | .temp4_input')
  CPU3=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 3" | .temp5_input')
  CPUP=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Package id 0" | .temp1_input')

  logger -t ilo4_fan_manager -p user.debug "CPU0: $CPU0 | CPU1: $CPU1 | CPU2: $CPU2 | CPU3: $CPU3 | CPU Package: $CPUP | SSD: $HDD1 | HDD2: $HDD2 | HDD3: $HDD3 | HDD4: $HDD4"

  if [[ $HDD1 -ge $HDD_CRITICAL_TEMP || $HDD2 -ge $HDD_CRITICAL_TEMP || $HDD3 -ge $HDD_CRITICAL_TEMP || $HDD4 -ge $HDD_CRITICAL_TEMP || $CPU0 -ge $CPU_CRITICAL_TEMP || $CPU1 -ge $CPU_CRITICAL_TEMP || $CPU2 -ge $CPU_CRITICAL_TEMP || $CPU3 -ge $CPU_CRITICAL_TEMP || $CPUP -ge $CPU_CRITICAL_TEMP ]]; then
    if [[ $CRIT_TEMP_FLAG == "False" ]]; then
      set_fanspeed "$MAX" "$CRIT_MIN" || {
        sleep 60
        continue
      }
      subject="[HP Server] [ALERT] Server is boiling!"
      body="TEMPERATURES:\n
SSD: $HDD1
HDD2: $HDD2
HDD3: $HDD3
HDD4: $HDD4
CPU0: $CPU0
CPU1: $CPU1
CPU2: $CPU2
CPU3: $CPU3
CPU Package: $CPUP"
      message="Subject: $subject\n\n$body"
      send_email "$message"
    fi
    if [[ $CRIT_TEMP_FLAG == "True" ]]; then
      subject="[HP Server] [ALERT] Server is shutting down!"
      body="TEMPERATURES:\n
SSD: $HDD1
HDD2: $HDD2
HDD3: $HDD3
HDD4: $HDD4
CPU0: $CPU0
CPU1: $CPU1
CPU2: $CPU2
CPU3: $CPU3
CPU Package: $CPUP
FLAG: $CRIT_TEMP_FLAG"
      message="Subject: $subject\n\n$body"
      send_email "$message"
      shutdown
    else
      unset_flags
      CRIT_TEMP_FLAG="True"
      logger -t ilo4_fan_manager -p user.warning "CRIT_TEMP_FLAG=$CRIT_TEMP_FLAG"
    fi

  elif [[ $HDD1 -ge $HDD_PERC90 || $HDD2 -ge $HDD_PERC90 || $HDD3 -ge $HDD_PERC90 || $HDD4 -ge $HDD_PERC90 || $CPU0 -ge $CPU_PERC90 || $CPU1 -ge $CPU_PERC90 || $CPU2 -ge $CPU_PERC90 || $CPU3 -ge $CPU_PERC90 || $CPUP -ge $CPU_PERC90 ]]; then
    if [[ $F9 == "False" ]]; then
      set_fanspeed "$MAX" "$PERC90_MIN" || {
        sleep 60
        continue
      }
    fi
    unset_flags
    F9="True"
    logger -t ilo4_fan_manager -p user.debug "F9=$F9"

  elif [[ $HDD1 -ge $HDD_PERC80 || $HDD2 -ge $HDD_PERC80 || $HDD3 -ge $HDD_PERC80 || $HDD4 -ge $HDD_PERC80 || $CPU0 -ge $CPU_PERC80 || $CPU1 -ge $CPU_PERC80 || $CPU2 -ge $CPU_PERC80 || $CPU3 -ge $CPU_PERC80 || $CPUP -ge $CPU_PERC80 ]]; then
    if [[ $F8 == "False" ]]; then
      set_fanspeed "$MAX" "$PERC80_MIN" || {
        sleep 60
        continue
      }
    fi
    unset_flags
    F8="True"
    logger -t ilo4_fan_manager -p user.debug "F8=$F8"

  elif [[ $HDD1 -ge $HDD_PERC70 || $HDD2 -ge $HDD_PERC70 || $HDD3 -ge $HDD_PERC70 || $HDD4 -ge $HDD_PERC70 || $CPU0 -ge $CPU_PERC70 || $CPU1 -ge $CPU_PERC70 || $CPU2 -ge $CPU_PERC70 || $CPU3 -ge $CPU_PERC70 || $CPUP -ge $CPU_PERC70 ]]; then
    if [[ $F7 == "False" ]]; then
      set_fanspeed "$MAX" "$PERC70_MIN" || {
        sleep 60
        continue
      }
    fi
    unset_flags
    F7="True"
    logger -t ilo4_fan_manager -p user.debug "F7=$F7"

  elif [[ $HDD1 -ge $HDD_PERC60 || $HDD2 -ge $HDD_PERC60 || $HDD3 -ge $HDD_PERC60 || $HDD4 -ge $HDD_PERC60 || $CPU0 -ge $CPU_PERC60 || $CPU1 -ge $CPU_PERC60 || $CPU2 -ge $CPU_PERC60 || $CPU3 -ge $CPU_PERC60 || $CPUP -ge $CPU_PERC60 ]]; then
    if [[ $F6 == "False" ]]; then
      set_fanspeed "$MAX" "$PERC60_MIN" || {
        sleep 60
        continue
      }
    fi
    unset_flags
    F6="True"
    logger -t ilo4_fan_manager -p user.debug "F6=$F6"

  elif [[ $HDD1 -ge $HDD_PERC50 || $HDD2 -ge $HDD_PERC50 || $HDD3 -ge $HDD_PERC50 || $HDD4 -ge $HDD_PERC50 || $CPU0 -ge $CPU_PERC50 || $CPU1 -ge $CPU_PERC50 || $CPU2 -ge $CPU_PERC50 || $CPU3 -ge $CPU_PERC50 || $CPUP -ge $CPU_PERC50 ]]; then
    if [[ $F5 == "False" ]]; then
      set_fanspeed "$MAX" "$PERC50_MIN" || {
        sleep 60
        continue
      }
    fi
    unset_flags
    F5="True"
    logger -t ilo4_fan_manager -p user.debug "F5=$F5"

  elif [[ $HDD1 -ge $HDD_PERC40 || $HDD2 -ge $HDD_PERC40 || $HDD3 -ge $HDD_PERC40 || $HDD4 -ge $HDD_PERC40 || $CPU0 -ge $CPU_PERC40 || $CPU1 -ge $CPU_PERC40 || $CPU2 -ge $CPU_PERC40 || $CPU3 -ge $CPU_PERC40 || $CPUP -ge $CPU_PERC40 ]]; then
    if [[ $F4 == "False" ]]; then
      set_fanspeed "$MAX" "$PERC40_MIN" || {
        sleep 60
        continue
      }
    fi
    unset_flags
    F4="True"
    logger -t ilo4_fan_manager -p user.debug "F4=$F4"

  elif [[ $HDD1 -gt $HDD_PERC30 || $HDD2 -gt $HDD_PERC30 || $HDD3 -gt $HDD_PERC30 || $HDD4 -gt $HDD_PERC30 || $CPU0 -gt $CPU_PERC30 || $CPU1 -gt $CPU_PERC30 || $CPU2 -gt $CPU_PERC30 || $CPU3 -gt $CPU_PERC30 || $CPUP -gt $CPU_PERC30 ]]; then
    if [[ $F3 == "False" ]]; then
      set_fanspeed "$MAX" "$PERC30_MIN" || {
        sleep 60
        continue
      }
    fi
    unset_flags
    F3="True"
    logger -t ilo4_fan_manager -p user.debug "F3=$F3"

  else
    if [[ $COLD_TEMP_FLAG == "False" ]]; then
      set_fanspeed "$COLD_MAX" "$COLD_MIN" || {
        sleep 60
        continue
      }
      unset_flags
      COLD_TEMP_FLAG="True"
      logger -t ilo4_fan_manager -p user.warning "COLD_TEMP_FLAG=$COLD_TEMP_FLAG"
      subject="[HP Server] [ALERT] Server is freezing!"
      body="TEMPERATURES:\n
SSD: $HDD1
HDD2: $HDD2
HDD3: $HDD3
HDD4: $HDD4
CPU0: $CPU0
CPU1: $CPU1
CPU2: $CPU2
CPU3: $CPU3
CPU Package: $CPUP"
      message="Subject: $subject\n\n$body"
      send_email "$message"
    fi
  fi
  sleep "$FREQ"
done
