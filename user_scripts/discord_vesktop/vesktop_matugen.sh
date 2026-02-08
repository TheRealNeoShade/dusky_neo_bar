#!/usr/bin/env bash

# ==============================================================================
#  Vesktop & Matugen Automation Suite
#  Target: Arch Linux (Hyprland) | Deps: yay/paru, jq
# ==============================================================================

# 1. Strict Mode & Error Handling
set -euo pipefail
IFS=$'\n\t'

# 2. Formatting Constants
readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly BLUE=$'\033[0;34m'
readonly YELLOW=$'\033[1;33m'
readonly NC=$'\033[0m' # No Color

# 3. Cleanup Trap
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        printf "${RED}[!] Script failed with exit code %d${NC}\n" "$exit_code"
    fi
}
trap cleanup EXIT

# 4. Helper Functions
log_info()    { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
log_success() { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
log_warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$1"; exit 1; }

# 5. Privilege Check (MUST RUN AS USER)
if [[ $EUID -eq 0 ]]; then
    log_error "This script must NOT be run as root. It modifies user configs and uses AUR helpers."
fi

# 6. Detect AUR Helper
AUR_HELPER=""
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
else
    log_error "Neither 'paru' nor 'yay' found. Please install an AUR helper."
fi

# ==============================================================================
#  Phase 1: Installation
# ==============================================================================
log_info "Phase 1: Package Management..."

# Ensure JQ is installed (Vital for JSON editing)
if ! command -v jq &>/dev/null; then
    log_info "Installing dependency: jq..."
    sudo pacman -S --needed --noconfirm jq
fi

# Install vesktop-bin
if pacman -Qi vesktop-bin &>/dev/null; then
    log_success "vesktop-bin is already installed."
else
    log_info "Installing vesktop-bin via $AUR_HELPER..."
    "$AUR_HELPER" -S --needed --noconfirm vesktop-bin
fi

# ==============================================================================
#  Phase 2: Matugen Configuration
# ==============================================================================
log_info "Phase 2: Configuring Matugen..."

MATUGEN_CONFIG="$HOME/.config/matugen/config.toml"
MATUGEN_DIR="$(dirname "$MATUGEN_CONFIG")"
mkdir -p "$MATUGEN_DIR"

# The specific block to inject/ensure
read -r -d '' VESKTOP_BLOCK << EOM || true
[templates.vesktop]
input_path  = '~/.config/matugen/templates/midnight-discord.css'
output_path = '~/.config/matugen/generated/midnight-discord.css'
post_hook   = '''
mkdir -p \$HOME/.config/vesktop/themes/;
ln -nfs \$HOME/.config/matugen/generated/midnight-discord.css \$HOME/.config/vesktop/themes/midnight-discord.css
'''
EOM

# Check if file exists
if [[ ! -f "$MATUGEN_CONFIG" ]]; then
    log_info "Matugen config missing. Creating..."
    echo "$VESKTOP_BLOCK" > "$MATUGEN_CONFIG"
    log_success "Created matugen config."
else
    # Check if [templates.vesktop] exists
    if grep -q "\[templates.vesktop\]" "$MATUGEN_CONFIG"; then
        # Check if it's commented out
        if grep -q "^[[:space:]]*#[[:space:]]*\[templates.vesktop\]" "$MATUGEN_CONFIG"; then
            log_info "Found commented Vesktop template. Uncommenting..."
            # Use sed to uncomment the block. 
            # Note: This simple regex assumes standard commenting.
            sed -i '/\[templates.vesktop\]/,/'''/ s/^[[:space:]]*#//' "$MATUGEN_CONFIG"
            log_success "Uncommented Vesktop template."
        else
            log_success "Vesktop template already active in Matugen config."
        fi
    else
        log_info "Appending Vesktop template to Matugen config..."
        echo -e "\n$VESKTOP_BLOCK" >> "$MATUGEN_CONFIG"
        log_success "Appended Vesktop template."
    fi
fi

# ==============================================================================
#  Phase 3: Pre-emptively Create Theme Symlink
# ==============================================================================
# We mimic the Matugen hook here so the theme exists even if Matugen hasn't run yet.
log_info "Phase 3: Enforcing Theme Files..."

# Create dirs
mkdir -p "$HOME/.config/vesktop/themes/"
mkdir -p "$HOME/.config/matugen/generated/"

# Define paths
SOURCE_CSS="$HOME/.config/matugen/generated/midnight-discord.css"
TARGET_LINK="$HOME/.config/vesktop/themes/midnight-discord.css"

# Create dummy source if it doesn't exist yet (to prevent broken link)
# Ideally Matugen generates this, but we want the setting to be valid now.
if [[ ! -f "$SOURCE_CSS" ]]; then
    log_warn "Generated CSS not found. Creating placeholder to allow Vesktop to load..."
    touch "$SOURCE_CSS"
fi

# Link
ln -nfs "$SOURCE_CSS" "$TARGET_LINK"
log_success "Symlinked midnight-discord.css to Vesktop themes."

# ==============================================================================
#  Phase 4: Vesktop Settings Injection
# ==============================================================================
log_info "Phase 4: Injecting Vesktop Settings..."

SETTINGS_DIR="$HOME/.config/vesktop/settings"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"
mkdir -p "$SETTINGS_DIR"

THEME_NAME="midnight-discord.css"

# Default JSON Configuration (Minified for script cleanliness)
# Using the exact structure requested
read -r -d '' DEFAULT_SETTINGS << EOM || true
{
  "autoUpdate": true,
  "autoUpdateNotification": true,
  "useQuickCss": true,
  "themeLinks": [],
  "eagerPatches": false,
  "enabledThemes": ["$THEME_NAME"],
  "enableReactDevtools": false,
  "frameless": false,
  "transparent": false,
  "winCtrlQ": false,
  "disableMinSize": false,
  "winNativeTitleBar": false,
  "plugins": {
    "ChatInputButtonAPI": { "enabled": false },
    "CommandsAPI": { "enabled": true },
    "DynamicImageModalAPI": { "enabled": false },
    "MemberListDecoratorsAPI": { "enabled": false },
    "MessageAccessoriesAPI": { "enabled": true },
    "MessageDecorationsAPI": { "enabled": false },
    "MessageEventsAPI": { "enabled": false },
    "MessagePopoverAPI": { "enabled": false },
    "MessageUpdaterAPI": { "enabled": false },
    "ServerListAPI": { "enabled": false },
    "UserSettingsAPI": { "enabled": true },
    "AccountPanelServerProfile": { "enabled": false },
    "AlwaysAnimate": { "enabled": false },
    "AlwaysExpandRoles": { "enabled": false },
    "AlwaysTrust": { "enabled": false },
    "AnonymiseFileNames": { "enabled": false },
    "AppleMusicRichPresence": { "enabled": false },
    "WebRichPresence (arRPC)": { "enabled": false },
    "BetterFolders": { "enabled": false },
    "BetterGifAltText": { "enabled": false },
    "BetterGifPicker": { "enabled": false },
    "BetterNotesBox": { "enabled": false },
    "BetterRoleContext": { "enabled": false },
    "BetterRoleDot": { "enabled": false },
    "BetterSessions": { "enabled": false },
    "BetterSettings": { "enabled": false },
    "BetterUploadButton": { "enabled": false },
    "BiggerStreamPreview": { "enabled": false },
    "BlurNSFW": { "enabled": false },
    "CallTimer": { "enabled": false },
    "ClearURLs": { "enabled": false },
    "ClientTheme": { "enabled": false },
    "ColorSighted": { "enabled": false },
    "ConsoleJanitor": { "enabled": false },
    "ConsoleShortcuts": { "enabled": false },
    "CopyEmojiMarkdown": { "enabled": false },
    "CopyFileContents": { "enabled": false },
    "CopyStickerLinks": { "enabled": false },
    "CopyUserURLs": { "enabled": false },
    "CrashHandler": { "enabled": true },
    "CtrlEnterSend": { "enabled": false },
    "CustomIdle": { "enabled": false },
    "CustomRPC": { "enabled": false },
    "Dearrow": { "enabled": false },
    "Decor": { "enabled": false },
    "DisableCallIdle": { "enabled": false },
    "DontRoundMyTimestamps": { "enabled": false },
    "Experiments": { "enabled": false },
    "ExpressionCloner": { "enabled": false },
    "F8Break": { "enabled": false },
    "FakeNitro": { "enabled": false },
    "FakeProfileThemes": { "enabled": false },
    "FavoriteEmojiFirst": { "enabled": false },
    "FavoriteGifSearch": { "enabled": false },
    "FixCodeblockGap": { "enabled": false },
    "FixImagesQuality": { "enabled": false },
    "FixSpotifyEmbeds": { "enabled": false },
    "FixYoutubeEmbeds": { "enabled": false },
    "ForceOwnerCrown": { "enabled": false },
    "FriendInvites": { "enabled": false },
    "FriendsSince": { "enabled": false },
    "FullSearchContext": { "enabled": false },
    "FullUserInChatbox": { "enabled": false },
    "GameActivityToggle": { "enabled": false },
    "GifPaste": { "enabled": false },
    "GreetStickerPicker": { "enabled": false },
    "HideMedia": { "enabled": false },
    "iLoveSpam": { "enabled": false },
    "IgnoreActivities": { "enabled": false },
    "ImageFilename": { "enabled": false },
    "ImageLink": { "enabled": false },
    "ImageZoom": { "enabled": false },
    "ImplicitRelationships": { "enabled": false },
    "IrcColors": { "enabled": false },
    "KeepCurrentChannel": { "enabled": false },
    "LastFMRichPresence": { "enabled": false },
    "LoadingQuotes": { "enabled": false },
    "MemberCount": { "enabled": false },
    "MentionAvatars": { "enabled": false },
    "MessageClickActions": { "enabled": false },
    "MessageLatency": { "enabled": false },
    "MessageLinkEmbeds": { "enabled": false },
    "MessageLogger": { "enabled": false },
    "MessageTags": { "enabled": false },
    "MoreQuickReactions": { "enabled": false },
    "MutualGroupDMs": { "enabled": false },
    "NewGuildSettings": { "enabled": false },
    "NoBlockedMessages": { "enabled": false },
    "NoDevtoolsWarning": { "enabled": false },
    "NoF1": { "enabled": false },
    "NoMaskedUrlPaste": { "enabled": false },
    "NoMosaic": { "enabled": false },
    "NoOnboardingDelay": { "enabled": false },
    "NoPendingCount": { "enabled": false },
    "NoProfileThemes": { "enabled": false },
    "NoReplyMention": { "enabled": false },
    "NoServerEmojis": { "enabled": false },
    "NoTypingAnimation": { "enabled": false },
    "NoUnblockToJump": { "enabled": false },
    "NotificationVolume": { "enabled": false },
    "OnePingPerDM": { "enabled": false },
    "oneko": { "enabled": false },
    "OpenInApp": { "enabled": false },
    "OverrideForumDefaults": { "enabled": false },
    "PauseInvitesForever": { "enabled": false },
    "PermissionFreeWill": { "enabled": false },
    "PermissionsViewer": { "enabled": false },
    "petpet": { "enabled": false },
    "PictureInPicture": { "enabled": false },
    "PinDMs": { "enabled": false },
    "PlainFolderIcon": { "enabled": false },
    "PlatformIndicators": { "enabled": false },
    "PreviewMessage": { "enabled": false },
    "QuickMention": { "enabled": false },
    "QuickReply": { "enabled": false },
    "ReactErrorDecoder": { "enabled": false },
    "ReadAllNotificationsButton": { "enabled": false },
    "RelationshipNotifier": { "enabled": false },
    "ReplaceGoogleSearch": { "enabled": false },
    "ReplyTimestamp": { "enabled": false },
    "RevealAllSpoilers": { "enabled": false },
    "ReverseImageSearch": { "enabled": false },
    "ReviewDB": { "enabled": false },
    "RoleColorEverywhere": { "enabled": false },
    "SecretRingToneEnabler": { "enabled": false },
    "Summaries": { "enabled": false },
    "SendTimestamps": { "enabled": false },
    "ServerInfo": { "enabled": false },
    "ServerListIndicators": { "enabled": false },
    "ShikiCodeblocks": { "enabled": false },
    "ShowAllMessageButtons": { "enabled": false },
    "ShowConnections": { "enabled": false },
    "ShowHiddenChannels": { "enabled": false },
    "ShowHiddenThings": { "enabled": false },
    "ShowMeYourName": { "enabled": false },
    "ShowTimeoutDuration": { "enabled": false },
    "SilentMessageToggle": { "enabled": false },
    "SilentTyping": { "enabled": false },
    "SortFriendRequests": { "enabled": false },
    "SpotifyControls": { "enabled": false },
    "SpotifyCrack": { "enabled": false },
    "SpotifyShareCommands": { "enabled": false },
    "StartupTimings": { "enabled": false },
    "StickerPaste": { "enabled": false },
    "StreamerModeOnStream": { "enabled": false },
    "SuperReactionTweaks": { "enabled": false },
    "TextReplace": { "enabled": false },
    "ThemeAttributes": { "enabled": false },
    "Translate": { "enabled": false },
    "TypingIndicator": { "enabled": false },
    "TypingTweaks": { "enabled": false },
    "Unindent": { "enabled": false },
    "UnlockedAvatarZoom": { "enabled": false },
    "UnsuppressEmbeds": { "enabled": false },
    "UserMessagesPronouns": { "enabled": false },
    "UserVoiceShow": { "enabled": false },
    "USRBG": { "enabled": false },
    "ValidReply": { "enabled": false },
    "ValidUser": { "enabled": false },
    "VoiceChatDoubleClick": { "enabled": false },
    "VcNarrator": { "enabled": false },
    "VencordToolbox": { "enabled": false },
    "ViewIcons": { "enabled": false },
    "ViewRaw": { "enabled": false },
    "VoiceDownload": { "enabled": false },
    "VoiceMessages": { "enabled": false },
    "VolumeBooster": { "enabled": false },
    "WebKeybinds": { "enabled": true },
    "WebScreenShareFixes": { "enabled": true },
    "WhoReacted": { "enabled": false },
    "XSOverlay": { "enabled": false },
    "YoutubeAdblock": { "enabled": false },
    "BadgeAPI": { "enabled": true },
    "NoTrack": { "enabled": true, "disableAnalytics": true },
    "Settings": { "enabled": true, "settingsLocation": "aboveNitro" },
    "DisableDeepLinks": { "enabled": true },
    "SupportHelper": { "enabled": true },
    "WebContextMenus": { "enabled": true }
  },
  "uiElements": { "chatBarButtons": {}, "messagePopoverButtons": {} },
  "notifications": { "timeout": 5000, "position": "bottom-right", "useNative": "not-focused", "logLimit": 50 },
  "cloud": { "authenticated": false, "url": "https://api.vencord.dev/", "settingsSync": false, "settingsSyncVersion": 1770555218584 }
}
EOM

if [[ ! -f "$SETTINGS_FILE" ]]; then
    log_info "Settings file missing. Generating complete default configuration..."
    echo "$DEFAULT_SETTINGS" > "$SETTINGS_FILE"
    log_success "Generated settings.json with '$THEME_NAME' enabled."
else
    log_info "Settings file exists. Patching..."
    # Use JQ to ensure enabledThemes contains the theme
    # This logic checks if theme is in array, if not adds it.
    tmp=$(mktemp)
    jq --arg theme "$THEME_NAME" '
        if .enabledThemes == null then
            .enabledThemes = [$theme]
        elif (.enabledThemes | index($theme)) == null then
            .enabledThemes += [$theme]
        else
            .
        end
    ' "$SETTINGS_FILE" > "$tmp"
    mv "$tmp" "$SETTINGS_FILE"
    log_success "Patched settings.json: '$THEME_NAME' is enabled."
fi

log_success "Automation Complete. Vesktop is ready."
