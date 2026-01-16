#!/usr/bin/env bash
# power_saving/power_saver.sh
# MASTER ORCHESTRATOR
set -uo pipefail

# 1. Setup Environment
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR}/lib"
readonly MODULES_DIR="${SCRIPT_DIR}/modules"

# 2. Source Common Library
if [[ ! -f "${LIB_DIR}/common.sh" ]]; then
    echo "Error: ${LIB_DIR}/common.sh not found." >&2
    exit 1
fi
source "${LIB_DIR}/common.sh"

# 3. Check Dependencies
if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
    printf 'Error: Bash 4.4+ required\n' >&2; exit 1
fi
if ! has_cmd gum; then
    printf 'Error: gum is required. Run: sudo pacman -S gum\n' >&2; exit 1
fi

# 4. Interactive Prompts
clear
gum style --border double --margin "1" --padding "1 2" \
    --border-foreground 212 --foreground 212 \
    "ASUS TUF F15: POWER SAVER MASTER"

export POWER_SAVER_THEME="false"
gum style --foreground 245 --italic "Rationale: Light mode allows lower backlight brightness."
if gum confirm "Switch to Light Mode?" --affirmative "Yes" --negative "No"; then
    export POWER_SAVER_THEME="true"
    log_step "Theme switch queued."
fi

export POWER_SAVER_WIFI="false"
if gum confirm "Turn off Wi-Fi?" --affirmative "Yes" --negative "No"; then
    export POWER_SAVER_WIFI="true"
    log_step "Wi-Fi disable queued."
fi

# -----------------------------------------------------------------------------
# USER MODULES (Non-Root)
# -----------------------------------------------------------------------------
"${MODULES_DIR}/01_visuals.sh"
"${MODULES_DIR}/02_cleanup.sh"
"${MODULES_DIR}/03_hardware.sh"

# Run 06 (Animations) here as it usually doesn't need root
if [[ -x "${MODULES_DIR}/06_disable_animations.sh" ]]; then
    run_external_script "${MODULES_DIR}/06_disable_animations.sh" "Module 06: Disabling Animations..."
fi

# -----------------------------------------------------------------------------
# ROOT MODULES (Sudo Required)
# -----------------------------------------------------------------------------
echo
gum style --border normal --border-foreground 196 --foreground 196 "PRIVILEGE ESCALATION REQUIRED"
if sudo -v; then
    export SUDO_AUTHENTICATED=true
    
    # Run 04 (WiFi, BT, TLP)
    "${MODULES_DIR}/04_root_ops.sh"
    
    # Run 07 (Process Terminator) - Requires sudo
    if [[ -x "${MODULES_DIR}/07_process_terminator.sh" ]]; then
        spin_exec "Module 07: Running Process Terminator..." sudo "${MODULES_DIR}/07_process_terminator.sh"
    fi
else
    log_error "Authentication failed. Skipping root operations (04, 07)."
fi

# -----------------------------------------------------------------------------
# DEFERRED MODULES
# -----------------------------------------------------------------------------
"${MODULES_DIR}/05_theme.sh"

# Finish
echo
gum style --foreground 46 --bold "✓ DONE: Power Saving Mode Active"
sleep 1
