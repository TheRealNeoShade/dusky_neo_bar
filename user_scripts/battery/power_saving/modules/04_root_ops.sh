#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"

# Check if we have sudo privileges
if ! sudo -n true 2>/dev/null; then
    log_error "Root privileges missing. Skipping root module."
    exit 1
fi

echo
log_step "Module 04: Root Operations (Privileged)"

# 1. Bluetooth
if has_cmd rfkill; then
    spin_exec "Blocking Bluetooth..." sudo rfkill block bluetooth
    log_step "Bluetooth blocked."
fi

# 2. Wi-Fi (Conditional based on Env Var from Master)
if [[ "${POWER_SAVER_WIFI:-false}" == "true" ]]; then
    if has_cmd rfkill; then
        spin_exec "Blocking Wi-Fi (Hardware)..." sudo rfkill block wifi
        log_step "Wi-Fi blocked."
    fi
else
    log_step "Skipping Wi-Fi block (User request)."
fi

# 3. TLP
if has_cmd tlp; then
    spin_exec "Activating TLP power saver..." sudo tlp power-saver
    log_step "TLP power saver activated."
fi
