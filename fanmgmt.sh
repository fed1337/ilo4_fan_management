#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG="$SCRIPT_DIR/fanmgmt.conf"

source "$CONFIG"

function set_config() {
    sudo sed -i "s/^\($1\s*=\s*\).*\$/\1$2/" "$CONFIG"
}

# ignore invalid values for non-smart SSD
#HDD1=$(sudo smartctl -a /dev/sda | grep 194 | grep -Eo '[0-9.]+' | sed '7q;d')
HDD2=$(sudo smartctl -a /dev/sdb | grep 194 | grep -Eo '[0-9.]+' | sed '7q;d')
HDD3=$(sudo smartctl -a /dev/sdc | grep 194 | grep -Eo '[0-9.]+' | sed '7q;d')
HDD4=$(sudo smartctl -a /dev/sdd | grep 194 | grep -Eo '[0-9.]+' | sed '7q;d')

CPU0=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 0" | .temp2_input')
CPU1=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 1" | .temp3_input')
CPU2=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 2" | .temp4_input')
CPU3=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Core 3" | .temp5_input')
CPUP=$(sensors -Aj coretemp-isa-0000 | jq -s '.[] | .[] | ."Package id 0" | .temp1_input')

if [[ $HDD2 -ge $BOIL_HDD  || $HDD3 -ge $BOIL_HDD  || $HDD4 -ge $BOIL_HDD  || $CPU0 -ge $BOIL_CPU  || $CPU1 -ge $BOIL_CPU  || $CPU2 -ge $BOIL_CPU  || $CPU3 -ge $BOIL_CPU  || $CPUP -ge $BOIL_CPU ]]; then
  new_mode="boil"
elif [[ $HDD2 -ge $HOT_HDD  || $HDD3 -ge $HOT_HDD  || $HDD4 -ge $HOT_HDD  || $CPU0 -ge $HOT_CPU  || $CPU1 -ge $HOT_CPU  || $CPU2 -ge $HOT_CPU  || $CPU3 -ge $HOT_CPU  || $CPUP -ge $HOT_CPU ]]; then
  new_mode="hot"
elif [[ $HDD2 -ge $OKAY_HDD  || $HDD3 -ge $OKAY_HDD  || $HDD4 -ge $OKAY_HDD  || $CPU0 -ge $OKAY_CPU  || $CPU1 -ge $OKAY_CPU  || $CPU2 -ge $OKAY_CPU  || $CPU3 -ge $OKAY_CPU  || $CPUP -ge $OKAY_CPU ]]; then
  new_mode="okay"
elif [[ $HDD2 -ge $COOL_HDD  || $HDD3 -ge $COOL_HDD  || $HDD4 -ge $COOL_HDD  || $CPU0 -ge $COOL_CPU  || $CPU1 -ge $COOL_CPU  || $CPU2 -ge $COOL_CPU  || $CPU3 -ge $COOL_CPU  || $CPUP -ge $COOL_CPU ]]; then
  new_mode="cool"
else
  new_mode="cold"
fi

if [[ "$new_mode" != "$mode" ]]; then
  set_config mode $new_mode

  case $new_mode in

    boil)
      sshpass -p "$PASS" ssh -o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o HostKeyAlgorithms=ssh-dss -o StrictHostKeyChecking=no "$USER"@"$HOST" 'fan p 0 max 255'
      sshpass -p "$PASS" ssh -o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o HostKeyAlgorithms=ssh-dss -o StrictHostKeyChecking=no "$USER"@"$HOST" 'fan p 0 min 240'
      ;;
    hot)
      sshpass -p "$PASS" ssh -o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o HostKeyAlgorithms=ssh-dss -o StrictHostKeyChecking=no "$USER"@"$HOST" 'fan p 0 max 255'
      sshpass -p "$PASS" ssh -o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o HostKeyAlgorithms=ssh-dss -o StrictHostKeyChecking=no "$USER"@"$HOST" 'fan p 0 min 120'
      ;;
    okay)
      sshpass -p "$PASS" ssh -o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o HostKeyAlgorithms=ssh-dss -o StrictHostKeyChecking=no "$USER"@"$HOST" 'fan p 0 max 255'
      sshpass -p "$PASS" ssh -o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o HostKeyAlgorithms=ssh-dss -o StrictHostKeyChecking=no "$USER"@"$HOST" 'fan p 0 min 80'
      ;;
    cool)
      sshpass -p "$PASS" ssh -o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o HostKeyAlgorithms=ssh-dss -o StrictHostKeyChecking=no "$USER"@"$HOST" 'fan p 0 max 16'
      sshpass -p "$PASS" ssh -o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o HostKeyAlgorithms=ssh-dss -o StrictHostKeyChecking=no "$USER"@"$HOST" 'fan p 0 min 0'
      ;;
    cold)
      sshpass -p "$PASS" ssh -o KexAlgorithms=+diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o HostKeyAlgorithms=ssh-dss -o StrictHostKeyChecking=no "$USER"@"$HOST" 'fan p 0 max 1'
      ;;
  esac
fi

echo "$(date +"%F %H:%M:%S") | CPU0: $CPU0 | CPU1: $CPU1 | CPU2: $CPU2 | CPU3: $CPU3 | CPU Package: $CPUP | HDD2: $HDD2 | HDD3: $HDD3 | HDD4: $HDD4 | PREV_MODE: $mode | CUR_MODE: $new_mode" >> "$SCRIPT_DIR"/fanmgmt.log
