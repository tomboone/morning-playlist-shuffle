#!/bin/bash
# morning-shuffle.sh
# Shuffles and plays an Apple Music playlist every weekday morning.
# Reads settings from morning-shuffle.conf.
# Checks iCloud Drive flag file set by iPhone shortcut each evening.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF="$SCRIPT_DIR/morning-shuffle.conf"
LOG="$HOME/.morning-shuffle.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"
}

if [ ! -f "$CONF" ]; then
    log "ERROR: Config file not found at $CONF"
    exit 1
fi

source "$CONF"

log "=== Morning Shuffle starting ==="

# 1. Check the iCloud Drive flag directory for play/skip signal.
# Uses filenames (play.flag / skip.flag) instead of file content to avoid
# iCloud sync issues where file content isn't available after wake.
PLAY_FLAG="$FLAG_DIR/play.flag"
SKIP_FLAG="$FLAG_DIR/skip.flag"

if [ -f "$PLAY_FLAG" ]; then
    log "Found play.flag — playing today."
    rm -f "$PLAY_FLAG" "$SKIP_FLAG" 2>/dev/null
    log "Flag files cleared."
elif [ -f "$SKIP_FLAG" ]; then
    log "Found skip.flag — skipping today."
    rm -f "$PLAY_FLAG" "$SKIP_FLAG" 2>/dev/null
    exit 0
else
    log "No flag file found. Defaulting to skip."
    exit 0
fi

log "Playlist match: '$PLAYLIST_MATCH' | Device: $EQMAC_DEVICE | Volume: $VOLUME | System Volume: $SYSTEM_VOLUME"

# 2. Launch Music.app and wait for system services to settle after wake.
# Subscription playlists need Music.app fully connected to Apple Music servers.
open -a Music
log "Launched Music.app"
sleep 20

# 3. Set audio output to eqMac's virtual device
if command -v SwitchAudioSource &> /dev/null; then
    CURRENT=$(SwitchAudioSource -c 2>/dev/null)
    log "Current audio device: $CURRENT"
    SwitchAudioSource -s "$EQMAC_DEVICE" 2>/dev/null
    if [ $? -eq 0 ]; then
        log "Audio output set to: $EQMAC_DEVICE"
    else
        log "WARNING: Could not set audio output to $EQMAC_DEVICE"
    fi
elif [ -f /usr/local/bin/SwitchAudioSource ]; then
    /usr/local/bin/SwitchAudioSource -s "$EQMAC_DEVICE"
elif [ -f /opt/homebrew/bin/SwitchAudioSource ]; then
    /opt/homebrew/bin/SwitchAudioSource -s "$EQMAC_DEVICE"
else
    log "WARNING: SwitchAudioSource not found. Install with: brew install switchaudio-osx"
fi

# 4. Small delay for audio device to settle
sleep 2

# 5. Set system volume
osascript -e "set volume output volume $SYSTEM_VOLUME"
log "System volume set to: $SYSTEM_VOLUME"

# 6. Shuffle and play the playlist via AppleScript
# Uses "contains" matching to handle all playlist types (user, subscription)
# and Unicode issues (e.g. curly quotes in Apple Music playlist names).
# PLAYLIST_MATCH is comma-separated; all terms must match.

# Build AppleScript "contains" conditions from comma-separated PLAYLIST_MATCH
IFS=',' read -ra TERMS <<< "$PLAYLIST_MATCH"
CONDITION=""
for term in "${TERMS[@]}"; do
    term=$(echo "$term" | xargs)  # trim whitespace
    if [ -z "$CONDITION" ]; then
        CONDITION="name of p contains \"$term\""
    else
        CONDITION="$CONDITION and name of p contains \"$term\""
    fi
done

RESULT=""
MAX_ATTEMPTS=5
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    RESULT=$(osascript <<EOF
tell application "Music"
    repeat with p in (every playlist)
        if $CONDITION then
            set shuffle enabled to true
            play p
            set sound volume to $VOLUME
            return "Playing: " & name of p
        end if
    end repeat
    return "Not found"
end tell
EOF
    )

    if [[ "$RESULT" == Playing* ]]; then
        log "$RESULT"
        break
    fi

    log "Attempt $ATTEMPT/$MAX_ATTEMPTS: Playlist not found. Retrying in 15s..."
    ATTEMPT=$((ATTEMPT + 1))
    sleep 15
done

if [[ "$RESULT" != Playing* ]]; then
    log "ERROR: Playlist not found matching '$PLAYLIST_MATCH' after $MAX_ATTEMPTS attempts."
fi

log "=== Morning Shuffle complete ==="
