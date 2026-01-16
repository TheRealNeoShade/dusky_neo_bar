#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"

echo
log_step "Module: Cleanup Processes"

# 1. Kill resource monitors
spin_exec "Cleaning up resource monitors..." \
    bash -c 'pkill -x btop 2>/dev/null; pkill -x nvtop 2>/dev/null; exit 0'

# 2. Pause media
if has_cmd playerctl; then
    run_quiet playerctl -a pause
fi
log_step "Resource monitors killed & media paused."

# 3. Warp VPN
if has_cmd warp-cli; then
    spin_exec "Disconnecting Warp..." \
        bash -c 'warp-cli disconnect &>/dev/null || true'
    log_step "Warp disconnected."
fi
