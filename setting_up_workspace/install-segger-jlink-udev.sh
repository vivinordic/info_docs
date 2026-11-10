#!/usr/bin/env bash
# Install SEGGER udev rules so non-root users can open J-Link USB (required for
# nrfutil device program / west flash). nrf-udev (Nordic 1915) does not cover
# the SEGGER probe interface (1366:1065, 1366:1069 on DKs).
set -euo pipefail

JLINK_DIR="${JLINK_DIR:-/home/user/opt/JLink_Linux_V924a_x86_64}"
RULES_SRC="${JLINK_DIR}/99-jlink.rules"
RULES_DST="/etc/udev/rules.d/99-jlink.rules"

if [[ ! -f "${RULES_SRC}" ]]; then
	echo "Missing ${RULES_SRC}. Set JLINK_DIR to your J-Link install." >&2
	exit 1
fi

echo "Installing ${RULES_SRC} -> ${RULES_DST}"
sudo cp "${RULES_SRC}" "${RULES_DST}"
sudo udevadm control --reload-rules
sudo udevadm trigger
echo "Done. Unplug and replug DK USB, or wait a few seconds, then test:"
echo "  JLinkExe  (should connect, not 'Cannot connect to J-Link')"
echo "  west flash --snr <serial>"
