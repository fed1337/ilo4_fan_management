#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "ILO4 Fan manager install script must run as root!" >&2
  exit 1
fi

APP_NAME="ilo4_fan_manager"
INSTALL_DIR="/usr/local/bin"
CONFIG_FILE="/etc/ilo4_fan_manager.conf"
SOURCE_DIR="$(dirname "$(readlink -f "$0")")"

echo "📄 Installing ILO4 Fan Manager..."

install -m 0744 "$SOURCE_DIR/$APP_NAME.sh" "$INSTALL_DIR"

if [[ ! -f "$CONFIG_FILE" ]]; then
  install -m 0644 "$SOURCE_DIR/$APP_NAME.conf" "/etc"
else
  echo "✅ Config already exists at $CONFIG_FILE. No alternations were made"
fi

echo "🔧Installing systemd service."
install -m 0644 "$SOURCE_DIR/$APP_NAME.service" /etc/systemd/system
systemctl daemon-reload
systemctl enable "$APP_NAME"
systemctl start "$APP_NAME"

echo -e "✅ ILO4 Fan Manager successfully installed to $INSTALL_DIR
✅ Config is located at $CONFIG_FILE"
