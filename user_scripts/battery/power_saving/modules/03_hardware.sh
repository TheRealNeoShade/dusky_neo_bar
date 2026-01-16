#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"

echo
log_step "Module: User Hardware Control"

# 1. Brightness
if has_cmd brightnessctl; then
    spin_exec "Lowering brightness to ${BRIGHTNESS_LEVEL}..." \
        brightnessctl set "${BRIGHTNESS_LEVEL}" -q
    log_step "Brightness set to ${BRIGHTNESS_LEVEL}."
else
    log_warn "brightnessctl not found."
fi

# 2. Asus Profile
run_external_script "${ASUS_PROFILE_SCRIPT}" "Applying Quiet Profile & KB Lights..."

# 3. Volume Cap (User level via wpctl)
if has_cmd wpctl; then
    if raw_output=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); then
        current_vol=$(awk '{printf "%.0f", $2 * 100}' <<< "${raw_output}")
        
        if is_numeric "${current_vol}" && ((current_vol > VOLUME_CAP)); then
            spin_exec "Volume ${current_vol}% → ${VOLUME_CAP}%..." \
                wpctl set-volume @DEFAULT_AUDIO_SINK@ "${VOLUME_CAP}%"
            log_step "Volume capped at ${VOLUME_CAP}%."
        else
            log_step "Volume check passed."
        fi
    fi
else
    log_warn "wpctl not found."
fi
