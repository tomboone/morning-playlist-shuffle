#!/bin/bash
# morning-shuffle-install.sh
# Reads morning-shuffle.conf and (re)installs the launchd agent and pmset schedule.
# Run this after any changes to the config file.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF="$SCRIPT_DIR/morning-shuffle.conf"
PLIST_NAME="com.user.morning-shuffle"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

if [ ! -f "$CONF" ]; then
    echo "ERROR: Config file not found at $CONF"
    exit 1
fi

source "$CONF"

# Calculate wake time: 5 minutes before play time
WAKE_MINUTE=$((PLAY_MINUTE - 5))
WAKE_HOUR=$PLAY_HOUR
if [ $WAKE_MINUTE -lt 0 ]; then
    WAKE_MINUTE=$((WAKE_MINUTE + 60))
    WAKE_HOUR=$((WAKE_HOUR - 1))
fi
WAKE_TIME=$(printf "%02d:%02d:00" $WAKE_HOUR $WAKE_MINUTE)

echo "=== Morning Shuffle Installer ==="
echo "Playlist:   $PLAYLIST_NAME"
echo "Play time:  $(printf '%02d:%02d' $PLAY_HOUR $PLAY_MINUTE)"
echo "Wake time:  $WAKE_TIME"
echo "Device:     $EQMAC_DEVICE"
echo "Volume:     $VOLUME"
echo ""

# 1. Unload existing agent if present
if launchctl list | grep -q "$PLIST_NAME" 2>/dev/null; then
    echo "Unloading existing launchd agent..."
    launchctl unload "$PLIST_DEST" 2>/dev/null
fi

# 2. Generate the plist
echo "Generating launchd plist..."
cat > "$PLIST_DEST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT_DIR/morning-shuffle.sh</string>
    </array>

    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Weekday</key><integer>1</integer>
            <key>Hour</key><integer>$PLAY_HOUR</integer>
            <key>Minute</key><integer>$PLAY_MINUTE</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>2</integer>
            <key>Hour</key><integer>$PLAY_HOUR</integer>
            <key>Minute</key><integer>$PLAY_MINUTE</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>3</integer>
            <key>Hour</key><integer>$PLAY_HOUR</integer>
            <key>Minute</key><integer>$PLAY_MINUTE</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>4</integer>
            <key>Hour</key><integer>$PLAY_HOUR</integer>
            <key>Minute</key><integer>$PLAY_MINUTE</integer>
        </dict>
        <dict>
            <key>Weekday</key><integer>5</integer>
            <key>Hour</key><integer>$PLAY_HOUR</integer>
            <key>Minute</key><integer>$PLAY_MINUTE</integer>
        </dict>
    </array>

    <key>StandardOutPath</key>
    <string>/tmp/morning-shuffle-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/morning-shuffle-stderr.log</string>
</dict>
</plist>
PLIST

# 3. Load the agent
echo "Loading launchd agent..."
launchctl load "$PLIST_DEST"

# 4. Set pmset wake schedule (requires sudo)
echo ""
echo "Setting scheduled wake for $WAKE_TIME (weekdays)..."
echo "This requires sudo:"
sudo pmset repeat wakeorpoweron MTWRF "$WAKE_TIME"

echo ""
echo "=== Done! ==="
echo "Verify with:"
echo "  launchctl list | grep morning-shuffle"
echo "  pmset -g sched"
echo ""
echo "To test now:  ~/Scripts/morning-shuffle.sh"
echo "To check log: cat ~/.morning-shuffle.log"
