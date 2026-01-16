#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"

# Only run if Master set the environment variable
if [[ "${POWER_SAVER_THEME:-false}" != "true" ]]; then
    run_quiet pkill swww-daemon
    log_step "swww-daemon terminated."
    exit 0
fi

echo
log_step "Module: Theme Switch"

if ! has_cmd uwsm-app; then
    log_error "uwsm-app required for theme switch."
    exit 1
fi

gum style --foreground 212 "Executing theme switch..."
gum style --foreground 240 "(Terminal may close - this is expected)"
sleep 1

if uwsm-app -- "${THEME_SCRIPT}" --mode light; then
    sleep 3
    run_quiet pkill swww-daemon
    log_step "Theme switched to light mode."
else
    log_error "Theme switch failed."
fi
