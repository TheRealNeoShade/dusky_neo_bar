#!/usr/bin/env bash
# ==============================================================================
#  ARCH LINUX UPDATE ORCHESTRATOR (v4.5 - Hardened & Optimized)
#  Description: Manages dotfile/system updates while preserving user tweaks.
#  Target:      Arch Linux / Hyprland / UWSM / Bash 5.0+
#  Repo Type:   Git Bare Repository (--git-dir=~/dusky --work-tree=~)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. ENVIRONMENT VALIDATION & STRICT MODE
# ------------------------------------------------------------------------------
set -euo pipefail
# Ensure 'set -e' propagates to subshells/command substitutions (Bash 4.4+)
shopt -s inherit_errexit 2>/dev/null || true 

if ((BASH_VERSINFO[0] < 5)); then
    printf 'Error: Bash 5.0+ required (found %s)\n' "$BASH_VERSION" >&2
    exit 1
fi

# Resolve absolute path to self immediately for reliable re-execution
declare -r SELF_PATH="$(realpath "$0")"

# ------------------------------------------------------------------------------
# 2. CONFIGURATION
# ------------------------------------------------------------------------------
# Paths
declare -r DOTFILES_GIT_DIR="${HOME}/dusky"
declare -r WORK_TREE="${HOME}"
declare -r SCRIPT_DIR="${HOME}/user_scripts/arch_setup_scripts/scripts"
declare -r LOG_BASE_DIR="${HOME}/Documents/logs"
declare -r LOCK_FILE="/tmp/arch-orchestrator.lock"

# Remote
declare -r REPO_URL="https://github.com/dusklinux/dusky"
declare -r BRANCH="main"

# Binaries - Validate existence immediately
declare -r GIT_BIN="$(command -v git)" || { printf 'Error: git not found\n' >&2; exit 1; }
declare -r BASH_BIN="$(command -v bash)" || { printf 'Error: bash not found\n' >&2; exit 1; }

# Runtime State
declare    SUDO_PID=""
declare    STASH_REF=""
declare    LOG_FILE=""
declare -a GIT_CMD=()
declare -a FAILED_SCRIPTS=()

# ------------------------------------------------------------------------------
# 3. TERMINAL COLORS
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
    declare -r CLR_RED=$'\e[1;31m'
    declare -r CLR_GRN=$'\e[1;32m'
    declare -r CLR_YLW=$'\e[1;33m'
    declare -r CLR_BLU=$'\e[1;34m'
    declare -r CLR_CYN=$'\e[1;36m'
    declare -r CLR_BOLD=$'\e[1m'
    declare -r CLR_RST=$'\e[0m'
else
    declare -r CLR_RED="" CLR_GRN="" CLR_YLW="" CLR_BLU="" CLR_CYN="" CLR_BOLD="" CLR_RST=""
fi

# ------------------------------------------------------------------------------
# 4. LOGGING SYSTEM
# ------------------------------------------------------------------------------
setup_logging() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Try to create user log dir, fallback to /tmp if it fails (permissions/readonly)
    if ! mkdir -p "$LOG_BASE_DIR" 2>/dev/null; then
        LOG_FILE="/tmp/dusky_update_${timestamp}.log"
        printf '%s[WARN]%s Could not create %s. Logging to %s\n' "$CLR_YLW" "$CLR_RST" "$LOG_BASE_DIR" "$LOG_FILE"
    else
        LOG_FILE="${LOG_BASE_DIR}/dusky_update_${timestamp}.log"
    fi

    # Ensure log file is writable
    if ! touch "$LOG_FILE" 2>/dev/null; then
        LOG_FILE="/tmp/dusky_update_${timestamp}.log"
        touch "$LOG_FILE" || { printf 'Error: Cannot create log file\n' >&2; exit 1; }
    fi
    
    # Header for the log file
    {
        printf '================================================================================\n'
        printf ' DUSKY UPDATE LOG - %s\n' "$timestamp"
        printf ' Kernel: %s\n' "$(uname -r)"
        printf ' User:   %s\n' "$USER"
        printf '================================================================================\n'
    } >> "$LOG_FILE"
}

# Pure Bash ANSI stripping (Faster than spawning sed)
strip_ansi() {
    local text="$1"
    # Remove common ANSI escape sequences
    while [[ "$text" =~ $'\e'\[[0-9\;]*[a-zA-Z] ]]; do
        text="${text//${BASH_REMATCH[0]}/}"
    done
    printf '%s' "$text"
}

log() {
    # Validate arguments
    if (($# < 2)); then
        printf '[LOG ERROR] log() requires level and message\n' >&2
        return 1
    fi

    local -r level="$1"
    local -r msg="$2"
    local timestamp
    timestamp=$(date +%H:%M:%S)
    local formatted_msg=""

    case "$level" in
        INFO)    formatted_msg=$(printf '%s[INFO]%s   %s' "$CLR_BLU" "$CLR_RST" "$msg") ;;
        OK)      formatted_msg=$(printf '%s[OK]%s     %s' "$CLR_GRN" "$CLR_RST" "$msg") ;;
        WARN)    formatted_msg=$(printf '%s[WARN]%s   %s' "$CLR_YLW" "$CLR_RST" "$msg") ;;
        ERROR)   formatted_msg=$(printf '%s[ERROR]%s  %s' "$CLR_RED" "$CLR_RST" "$msg") ;;
        SECTION) formatted_msg=$(printf '\n%s═══════ %s %s' "$CLR_CYN" "$msg" "$CLR_RST") ;;
        RAW)     formatted_msg="$msg" ;; 
        *)       formatted_msg=$(printf '[%s] %s' "$level" "$msg") ;;
    esac

    # Print to console (stderr for errors, stdout for others)
    if [[ "$level" == "ERROR" ]]; then
        printf '%s\n' "$formatted_msg" >&2
    else
        printf '%s\n' "$formatted_msg"
    fi

    # Print to file (strip ANSI codes) - only if LOG_FILE is valid
    if [[ -n "${LOG_FILE:-}" && -w "$LOG_FILE" ]]; then
        printf '[%s] [%s] %s\n' "$timestamp" "$level" "$(strip_ansi "$msg")" >> "$LOG_FILE"
    fi
}

# ------------------------------------------------------------------------------
# 5. THE PLAYLIST
# ------------------------------------------------------------------------------
declare -ra UPDATE_SEQUENCE=(
#    "U | 000_configure_uwsm_gpu.sh"
#    "U | 001_long_sleep_timeout.sh"
#    "S | 002_battery_limiter.sh"
#    "S | 003_pacman_config.sh"
#    "S | 004_pacman_reflector.sh"
#    "S | 005_package_installation.sh"
#    "U | 006_enabling_user_services.sh"
#    "S | 007_openssh_setup.sh"
#    "U | 008_changing_shell_zsh.sh"
#    "S | 009_aur_paru_fallback_yay.sh"
#    "S | 010_warp.sh"
#    "U | 011_paru_packages_optional.sh"
#    "S | 012_battery_limiter_again_dusk.sh"
#    "U | 013_paru_packages.sh"
#    "S | 014_aur_packages_sudo_services.sh"
#    "U | 015_aur_packages_user_services.sh"
#    "S | 016_create_mount_directories.sh"
#    "S | 017_pam_keyring.sh"
    "U | 018_copy_service_files.sh --default"
#    "U | 019_battery_notify_service.sh"
#    "U | 020_fc_cache_fv.sh"
#    "U | 021_matugen_directories.sh"
#    "U | 022_wallpapers_download.sh"
#    "U | 023_blur_shadow_opacity.sh"
#    "U | 024_swww_wallpaper_matugen.sh"
#    "U | 025_qtct_config.sh"
#    "U | 026_waypaper_config_reset.sh"
    "U | 027_animation_symlink.sh"
#    "S | 028_udev_usb_notify.sh"
#    "U | 029_terminal_default.sh"
#    "S | 030_dusk_fstab.sh"
#    "S | 031_firefox_symlink_parition.sh"
#    "S | 032_tlp_config.sh"
#    "S | 033_zram_configuration.sh"
#    "S | 034_zram_optimize_swappiness.sh"
#    "S | 035_powerkey_lid_close_behaviour.sh"
#    "S | 036_logrotate_optimization.sh"
#    "S | 037_faillock_timeout.sh"
#    "U | 038_non_asus_laptop.sh --auto"
#    "U | 039_file_manager_switch.sh"
#    "U | 040_swaync_dgpu_fix.sh --disable"
#    "S | 041_asusd_service_fix.sh"
#    "S | 042_ftp_arch.sh"
#    "U | 043_tldr_update.sh"
#    "U | 044_spotify.sh"
#    "U | 045_mouse_button_reverse.sh --right"
#    "U | 046_neovim_clean.sh"
#    "U | 047_neovim_lazy_sync.sh"
#    "U | 048_dusk_clipboard_errands_delete.sh --auto"
#    "S | 049_tty_autologin.sh"
#    "S | 050_system_services.sh"
#    "S | 051_initramfs_optimization.sh"
#    "U | 052_git_config.sh"
#    "U | 053_new_github_repo_to_backup.sh"
#    "U | 054_reconnect_and_push_new_changes_to_github.sh"
#    "S | 055_grub_optimization.sh"
#    "S | 056_systemdboot_optimization.sh"
#    "S | 057_hosts_files_block.sh"
#    "S | 058_gtk_root_symlink.sh"
#    "S | 059_preload_config.sh"
#    "U | 060_kokoro_cpu.sh"
#    "U | 061_faster_whisper_cpu.sh"
#    "S | 062_dns_systemd_resolve.sh"
#    "U | 063_hyprexpo_plugin.sh"
#    "U | 064_obsidian_pensive_vault_configure.sh"
#    "U | 065_cache_purge.sh"
#    "S | 066_arch_install_scripts_cleanup.sh"
#    "U | 067_cursor_theme_bibata_classic_modern.sh"
#    "S | 068_nvidia_open_source.sh"
#    "S | 069_waydroid_setup.sh"
#    "U | 070_reverting_sleep_timeout.sh"
#    "U | 071_clipboard_persistance.sh"
#    "S | 072_intel_media_sdk_check.sh"
    "U | 073_desktop_apps_username_setter.sh"
#    "U | 074_firefox_matugen_pywalfox.sh"
#    "U | 075_spicetify_matugen_setup.sh"
#    "U | 076_waybar_swap_config.sh"
#    "U | 077_mpv_setup.sh"
#    "U | 078_kokoro_gpu_setup.sh"
#    "U | 079_parakeet_gpu_setup.sh"
#    "S | 080_btrfs_zstd_compression_stats.sh"
#    "U | 081_key_sound_wayclick_setup.sh"
#    "U | 082_config_bat_notify.sh --default"
    "U | 083_set_thunar_terminal_kitty.sh"
    "U | 084_package_removal.sh --auto"
    "U | 085_wayclick_reset.sh"
)

# ==============================================================================
#  CORE ENGINE
# ==============================================================================

trim() {
    local str="$1"
    str="${str#"${str%%[![:space:]]*}"}"
    str="${str%"${str##*[![:space:]]}"}"
    printf '%s' "$str"
}

cleanup() {
    local -r exit_code=$?

    # Stop Sudo Keepalive
    if [[ -n "${SUDO_PID:-}" ]] && kill -0 "$SUDO_PID" 2>/dev/null; then
        kill "$SUDO_PID" 2>/dev/null || true
        wait "$SUDO_PID" 2>/dev/null || true
    fi

    # Only attempt stash recovery if we have an outstanding stash
    if [[ -n "${STASH_REF:-}" ]] && ((${#GIT_CMD[@]} > 0)); then
        printf '\n'
        log WARN "Interrupted with stashed changes!"
        log WARN "Attempting automatic recovery..."

        if "${GIT_CMD[@]}" stash pop --quiet 2>/dev/null >> "${LOG_FILE:-/dev/null}" 2>&1; then
            log OK "Your local modifications have been restored."
        else
            log ERROR "Automatic recovery failed."
            log ERROR "Your changes are safely stored. Recover manually with:"
            printf '    %sgit --git-dir="%s" --work-tree="%s" stash pop%s\n' \
                   "$CLR_YLW" "$DOTFILES_GIT_DIR" "$WORK_TREE" "$CLR_RST"
        fi
    fi

    # Release lock
    exec 9>&- 2>/dev/null || true
    rm -f "$LOCK_FILE" 2>/dev/null || true

    printf '\n'
    if ((${#FAILED_SCRIPTS[@]} > 0)); then
        log WARN "Completed with ${#FAILED_SCRIPTS[@]} failure(s). Check log: ${LOG_FILE:-N/A}"
        local script
        for script in "${FAILED_SCRIPTS[@]}"; do
            printf '    %s•%s %s\n' "$CLR_RED" "$CLR_RST" "$script"
        done
    elif [[ -n "${LOG_FILE:-}" ]]; then
        log OK "Orchestration complete. Log saved to: $LOG_FILE"
    fi

    # Function finishes and trap exits with original code
}

# Trap EXIT and common signals for graceful shutdown
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

init_sudo() {
    log INFO "Acquiring sudo privileges..."

    if ! sudo -v; then
        log ERROR "Sudo authentication failed."
        exit 1
    fi

    # Robust keepalive with parent process monitoring
    # If this script (parent) dies, the subshell will exit automatically on next check
    (
        trap 'exit 0' TERM
        while kill -0 $$ 2>/dev/null; do
            sleep 55
            sudo -n true 2>/dev/null || exit 0
        done
    ) &
    SUDO_PID=$!
    disown "$SUDO_PID" 2>/dev/null || true
}

pull_updates() {
    log SECTION "Synchronizing Dotfiles Repository"

    if [[ ! -d "$DOTFILES_GIT_DIR" ]]; then
        log ERROR "Dotfiles bare repository not found: $DOTFILES_GIT_DIR"
        return 1
    fi

    GIT_CMD=( "$GIT_BIN" --git-dir="$DOTFILES_GIT_DIR" --work-tree="$WORK_TREE" )
    
    # Force untracked file output to OFF (fixes noisy logs and log file bloat)
    "${GIT_CMD[@]}" config status.showUntrackedFiles no 2>/dev/null || true

    log INFO "Checking for local modifications..."

    if ! "${GIT_CMD[@]}" diff-index --quiet HEAD -- 2>/dev/null; then
        log WARN "Uncommitted changes detected in tracked files."
        log INFO "Stashing your changes for safe pull..."

        local stash_msg="orchestrator-auto-$(date +%Y%m%d-%H%M%S)"

        # --- RECOVERY MENU ---
        if ! "${GIT_CMD[@]}" stash push -m "$stash_msg" >> "$LOG_FILE" 2>&1; then
            log ERROR "Git stash failed. This usually indicates a corrupted git index."
            printf '\n'
            printf "%s[ACTION REQUIRED]%s Select a recovery method:\n" "$CLR_YLW" "$CLR_RST"
            printf "  1) Abort (Stop update, do nothing)\n"
            printf "  %s2) Fix Index (DEFAULT) - Resets index, keeps your file changes%s\n" "$CLR_GRN" "$CLR_RST"
            printf "  3) Discard Changes - Hard Reset (DANGEROUS)\n"
            printf '\n'
            
            local choice
            # Timeout set to 60s to prevent hanging on headless runs
            if ! read -r -t 60 -p "Enter choice [1-3] (default: 2, 60s timeout): " choice; then
                choice="2" # Default on timeout
                printf '\n'
                log INFO "Timeout - using default option 2"
            fi
            choice="${choice:-2}"
            
            case "$choice" in
                2)
                    log INFO "Resetting git index (preserving local files)..."
                    if "${GIT_CMD[@]}" reset >> "$LOG_FILE" 2>&1; then
                        log OK "Index reset. Retrying stash..."
                        if ! "${GIT_CMD[@]}" stash push -m "$stash_msg" >> "$LOG_FILE" 2>&1; then
                             log ERROR "Stash failed again even after reset. Aborting."
                             return 1
                        fi
                    else
                        log ERROR "Git reset failed."
                        return 1
                    fi
                    ;;
                3)
                    printf '\n'
                    printf "%s┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓%s\n" "$CLR_RED" "$CLR_RST"
                    printf "%s┃   WARNING: DATA LOSS IMMINENT                               ┃%s\n" "$CLR_RED" "$CLR_RST"
                    printf "%s┃   This will IRREVERSIBLY DELETE all uncommitted changes.    ┃%s\n" "$CLR_RED" "$CLR_RST"
                    printf "%s┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛%s\n" "$CLR_RED" "$CLR_RST"
                    
                    local confirm
                    read -r -t 30 -p "Are you absolutely sure? (type 'yes' to proceed): " confirm || confirm=""
                    if [[ "$confirm" == "yes" ]]; then
                        log WARN "Hard resetting repository to HEAD..."
                        if "${GIT_CMD[@]}" reset --hard HEAD >> "$LOG_FILE" 2>&1; then
                            log OK "Repository forcefully cleaned. Proceeding."
                        else
                             log ERROR "Git hard reset failed."
                             return 1
                        fi
                    else
                        log INFO "Aborted by user."
                        return 1
                    fi
                    ;;
                *)
                    log ERROR "Aborting by user request."
                    return 1
                    ;;
            esac
        fi
        # --- END RECOVERY MENU ---

        # Double check if stash was actually created
        if [[ -z "${STASH_REF:-}" ]]; then
             if "${GIT_CMD[@]}" stash list 2>/dev/null | grep -q "$stash_msg"; then
                 STASH_REF="$stash_msg"
                 log OK "Changes stashed: $stash_msg"
             fi
        fi
    fi

    log INFO "Pulling updates from $REPO_URL..."

    local git_output
    local git_rc=0
    
    # Use timeout to prevent hanging on bad networks
    if ! git_output=$(timeout 45s "${GIT_CMD[@]}" pull --rebase origin "$BRANCH" 2>&1); then
        git_rc=$?
        log WARN "Pull failed (exit code: $git_rc), attempting fetch from URL directly..."
        printf '%s\n' "$git_output" >> "$LOG_FILE"

        if ! timeout 45s "${GIT_CMD[@]}" fetch "$REPO_URL" "$BRANCH" >> "$LOG_FILE" 2>&1; then
            log ERROR "Network error or repository unreachable."
            if [[ -n "${STASH_REF:-}" ]]; then
                "${GIT_CMD[@]}" stash pop --quiet 2>/dev/null && STASH_REF=""
            fi
            return 1
        fi

        if ! git_output=$("${GIT_CMD[@]}" rebase FETCH_HEAD 2>&1); then
            log ERROR "Rebase failed. Possible merge conflicts."
            printf '%s\n' "$git_output" >> "$LOG_FILE"
            printf '\n%s[GIT ERROR]%s Check log for details.\n' "$CLR_RED" "$CLR_RST"
            log ERROR "Resolve with: git --git-dir=$DOTFILES_GIT_DIR --work-tree=$WORK_TREE status"
            
            if [[ -n "${STASH_REF:-}" ]]; then
                log WARN "Your local changes remain stashed as: $STASH_REF"
                STASH_REF=""  
            fi
            return 1
        fi
    else
        # Log successful output
        printf '%s\n' "$git_output" >> "$LOG_FILE"
    fi

    log OK "Repository updated successfully."

    if [[ -n "${STASH_REF:-}" ]]; then
        log INFO "Restoring your local modifications..."

        if "${GIT_CMD[@]}" stash pop >> "$LOG_FILE" 2>&1; then
            STASH_REF=""
            log OK "Your customizations have been re-applied."
        else
            log WARN "Merge conflict during stash pop!"
            log WARN "Resolve conflicts, then: git --git-dir=$DOTFILES_GIT_DIR --work-tree=$WORK_TREE stash drop"
            STASH_REF=""
        fi
    fi

    return 0
}

run_script() {
    # Validate arguments
    if (($# < 2)); then
        log ERROR "run_script requires mode and script arguments"
        return 1
    fi
    
    local -r mode="$1"
    local -r script="$2"
    shift 2
    local -a args=("$@")

    local -r script_path="${SCRIPT_DIR}/${script}"

    if [[ ! -f "$script_path" ]]; then
        log WARN "Script not found: $script"
        return 0
    fi

    if [[ ! -r "$script_path" ]]; then
        log WARN "Script not readable: $script"
        return 0
    fi

    if ((${#args[@]} > 0)); then
        printf '%s→%s %s %s\n' "$CLR_BLU" "$CLR_RST" "$script" "${args[*]}"
    else
        printf '%s→%s %s\n' "$CLR_BLU" "$CLR_RST" "$script"
    fi

    local rc=0
    case "$mode" in
        S)  
            if ((${#args[@]} > 0)); then
                sudo "$BASH_BIN" "$script_path" "${args[@]}" || rc=$?
            else
                sudo "$BASH_BIN" "$script_path" || rc=$?
            fi
            ;;
        U)  
            if ((${#args[@]} > 0)); then
                "$BASH_BIN" "$script_path" "${args[@]}" || rc=$?
            else
                "$BASH_BIN" "$script_path" || rc=$?
            fi
            ;;
        *)
            log WARN "Unknown mode '$mode' for $script"
            return 0
            ;;
    esac

    if ((rc != 0)); then
        log ERROR "$script exited with code $rc"
        FAILED_SCRIPTS+=("$script")
    fi

    return 0
}

main() {
    setup_logging
    
    # Acquire exclusive lock
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        log ERROR "Another instance is already running (lock: $LOCK_FILE)"
        exit 1
    fi

    # Calculate hash of THIS script before update (using absolute path)
    local self_hash_before
    if [[ -r "$SELF_PATH" ]]; then
        # Check if sha256sum exists (part of coreutils, standard on Arch)
        if command -v sha256sum >/dev/null; then
             self_hash_before=$(sha256sum "$SELF_PATH" 2>/dev/null | awk '{print $1}') || self_hash_before=""
        else
             # Fallback to md5sum if weirdly missing, though unlikely on Arch
             self_hash_before=$(md5sum "$SELF_PATH" 2>/dev/null | awk '{print $1}') || self_hash_before=""
        fi
    else
        self_hash_before=""
    fi

    init_sudo

    if ! pull_updates; then
        log WARN "Repository sync encountered errors."
        local cont
        if ! read -r -t 30 -p "Continue with local scripts anyway? [y/N] " cont; then
            cont="n"
            printf '\n'
        fi
        if [[ ! "$cont" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        # --- SELF-UPDATE CHECK ---
        if [[ -n "$self_hash_before" && -r "$SELF_PATH" ]]; then
            local self_hash_after
            if command -v sha256sum >/dev/null; then
                self_hash_after=$(sha256sum "$SELF_PATH" 2>/dev/null | awk '{print $1}') || self_hash_after=""
            else
                self_hash_after=$(md5sum "$SELF_PATH" 2>/dev/null | awk '{print $1}') || self_hash_after=""
            fi

            if [[ -n "$self_hash_after" && "$self_hash_before" != "$self_hash_after" ]]; then
                log SECTION "Self-Update Detected"
                log OK "The orchestrator script has been updated."
                log INFO "Reloading new version..."
                
                # Release lock before re-execing
                exec 9>&- 
                rm -f "$LOCK_FILE" 2>/dev/null || true
                
                # Clear stash ref so cleanup doesn't try to pop
                STASH_REF=""
                
                # Re-execute the new script with original arguments
                # Uses realpath to ensure we find the script even if CWD changed
                exec "$SELF_PATH" "$@"
            fi
        fi
    fi

    if [[ ! -d "$SCRIPT_DIR" ]]; then
        log ERROR "Script directory missing: $SCRIPT_DIR"
        exit 1
    fi

    log SECTION "Executing Update Sequence"

    local entry mode script_part script
    local -a parts args

    for entry in "${UPDATE_SEQUENCE[@]}"; do
        # Skip comments and empty lines
        [[ "$entry" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${entry//[[:space:]]/}" ]] && continue

        mode=$(trim "${entry%%|*}")
        script_part=$(trim "${entry#*|}")

        # Parse script and arguments
        read -ra parts <<< "$script_part"

        script="${parts[0]:-}"
        args=("${parts[@]:1}")

        if [[ -z "$script" ]]; then
            log WARN "Malformed playlist entry: $entry"
            continue
        fi

        run_script "$mode" "$script" "${args[@]}"
    done
}

main "$@"
