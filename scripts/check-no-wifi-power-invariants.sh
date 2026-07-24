#!/usr/bin/env bash
set -euo pipefail

# The removed Wi-Fi power-saving feature must stay gone. It launched iw/nmcli
# subprocesses from Settings and probed the radio whenever a stream started.
# This guard covers the user-facing control, backend entry points, subprocess
# commands, and documentation that advertised the feature.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

runtime_paths=(
  app
  packaging
  scripts
  README.md
)

patterns=(
  'checkWifiPowerSaveStatus'
  'isWifiPowerSaveOn'
  'setWifiPowerSave'
  'logWifiPowerSaveStatus'
  'wifiPowerSave'
  'power_save'
  '802-11-wireless\.powersave'
  'vibemis-wifi'
  'NetworkManager dispatcher'
  'Wi-Fi power-saving'
  'Wi-Fi power saving'
)

failed=0
for pattern in "${patterns[@]}"; do
  if grep -Erin --exclude="$(basename "$0")" "$pattern" "${runtime_paths[@]}"; then
    echo "ERROR: removed Wi-Fi power-saving feature found (pattern: $pattern)" >&2
    failed=1
  fi
done

if (( failed )); then
  exit 1
fi

echo "Wi-Fi power-saving removal invariants: PASS"
