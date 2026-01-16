#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"

echo
log_step "Module 01: Visual Effects"

# 1. Blur/Opacity/Shadow
if ! has_cmd uwsm-app; then
    log_warn "uwsm-app not found. Skipping visual effects."
else
    # Toggle Blur/Shadow off
    run_external_script "${BLUR_SCRIPT}" "Disabling blur/opacity/shadow..." off

    # Disable Hyprshade
    if has_cmd hyprshade; then
        spin_exec "Disabling Hyprshade..." uwsm-app -- hyprshade off
    fi
fi

log_step "Visual effects configuration complete."
