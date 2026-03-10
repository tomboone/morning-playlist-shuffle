# Morning Playlist Shuffle — Setup Guide

## What this does

Every weekday morning, your Mac will:

1. Wake from sleep (via `pmset`)
2. Check an iCloud Drive flag file to see if you said "yes" or "skip" the night before
3. If enabled: launch Music.app, set audio output to eqMac, and shuffle/play your chosen playlist

Each evening, your iPhone prompts you to decide whether music plays the next morning.

## Files

| File | Purpose |
|------|---------|
| `morning-shuffle.conf.example` | Template config — copy to `morning-shuffle.conf` and fill in your values |
| `morning-shuffle.conf` | Your actual config (git-ignored) |
| `morning-shuffle.sh` | Main script (reads conf, checks flag, plays music) |
| `morning-shuffle-install.sh` | Generates launchd plist and pmset schedule from conf |
| `.gitignore` | Excludes `morning-shuffle.conf` from version control |

## Prerequisites

```bash
brew install switchaudio-osx
```

Find your eqMac device name:

```bash
SwitchAudioSource -a
```

Find your Music.app volume and system volume levels:

```bash
osascript -e 'tell application "Music" to get sound volume'
osascript -e 'output volume of (get volume settings)'
```

## Mac Setup

### 1. Copy files to a permanent location

```bash
mkdir -p ~/Scripts
cp morning-shuffle.conf.example ~/Scripts/morning-shuffle.conf
cp morning-shuffle.sh morning-shuffle-install.sh ~/Scripts/
chmod +x ~/Scripts/morning-shuffle.sh ~/Scripts/morning-shuffle-install.sh
```

### 2. Edit the config

Open `~/Scripts/morning-shuffle.conf` and set:

- `PLAYLIST_MATCH` — comma-separated keywords that together uniquely identify your playlist (e.g. `Today,Indie Rock`). All keywords must match using "contains" logic. This works for both user and subscription playlists, and avoids Unicode issues with curly quotes in Apple Music names. A single keyword works too (e.g. `My Morning Mix`).
- `EQMAC_DEVICE` — device name from `SwitchAudioSource -a` (e.g. `USB_AUDIO_SYSTEM (eqMac)`)
- `PLAY_HOUR` and `PLAY_MINUTE` — when to start playback (default: 8:30)
- `VOLUME` — Music.app volume, 0–100
- `SYSTEM_VOLUME` — macOS system volume, 0–100
- `FLAG_FILE` — path to the iCloud Drive flag file. **Use a hardcoded absolute path** (e.g. `/Users/yourname/Library/...`) rather than `$HOME`, since launchd's environment may not resolve `$HOME` reliably.

### 3. Set system sleep timer

The system sleep timer must be long enough for the Mac to stay awake between the scheduled wake and script execution. If your sleep timer is very short (e.g. 1 minute), the Mac may go back to sleep before the script runs.

```bash
# Set to 15 minutes on AC power (adjust to your preference)
sudo pmset -c sleep 15
```

### 4. Create the iCloud Drive directory

```bash
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/MorningShuffle
```

### 5. Grant Automation permissions

Run the script once manually while your Mac is **unlocked**:

```bash
~/Scripts/morning-shuffle.sh
```

macOS will prompt you to allow Terminal to control Music.app. Click **OK**. This only needs to happen once.

### 6. Run the installer

```bash
~/Scripts/morning-shuffle-install.sh
```

This generates a launchd plist (scheduled for your configured time, weekdays only), loads it, and sets a `pmset` wake schedule 5 minutes before play time.

## iPhone Setup (Shortcuts)

Create a shortcut on your iPhone and set it to run as a nightly automation.

### Create the Shortcut

1. Open the **Shortcuts** app on your iPhone
2. Tap **+** to create a new shortcut, name it **"Play morning music tomorrow?"** (the name appears in the notification)
3. Add these actions in order:

   **a. Choose from Menu**
   - Prompt: `Play morning music tomorrow?`
   - Options: `Yes` and `Skip`

   **b. Under the "Yes" branch:**
   - Add a **Text** action, type: `play`
   - Add a **Save File** action:
     - Input: the Text action's output
     - Destination: `iCloud Drive > MorningShuffle`
     - Sub Path: `tomorrow.txt`
     - Ask Where to Save: **OFF**
     - Overwrite If File Exists: **ON**

   **c. Under the "Skip" branch:**
   - Add a **Text** action, type: `skip`
   - Add a **Save File** action (same settings as above)

The full shortcut flow:

```
Menu: "Play morning music tomorrow?"
├── Yes
│   ├── Text: "play"
│   └── Save File → iCloud Drive/MorningShuffle/tomorrow.txt
└── Skip
    ├── Text: "skip"
    └── Save File → iCloud Drive/MorningShuffle/tomorrow.txt
```

### Set Up the Automation

1. In Shortcuts, go to the **Automation** tab
2. Tap **+** → **Time of Day**
3. Set time to something like **9:00 PM** (or whenever works for you)
4. Set **Repeat** to **Weekly**, select **Mon, Tue, Wed, Thu, Sun**
   (Sun night covers Monday morning; Mon–Thu nights cover Tue–Fri mornings)
5. Set **Run Immediately** to OFF so it notifies you instead of running silently
6. Select the shortcut you created

That's it — each weekday evening you'll get a notification, tap it, and choose Yes or Skip.

## How the flag works

- If the flag file says `play` or `yes` → music plays, flag file is deleted
- If the flag file says `skip` or `no` → script exits silently, flag file is deleted
- If the flag file is empty → script exits silently, flag file is deleted
- If the flag file doesn't exist (e.g., you forgot to respond) → **music does not play by default**

The flag file is always cleared after being read, so each morning starts fresh. If you miss the evening prompt, there's no leftover flag and the script defaults to skip.

The script uses `brctl download` to force iCloud to download the flag file before reading it, in case macOS has evicted the file content to save disk space.

## How playlist matching works

The script uses AppleScript "contains" matching rather than exact name matching. This is necessary because:

- Apple Music subscription playlists don't respond to direct `playlist "Name"` references in AppleScript
- Apple Music often uses Unicode curly quotes (') instead of straight apostrophes in playlist names

The `PLAYLIST_MATCH` config takes comma-separated keywords. All must match for a playlist to be selected. For example, `Today,Indie Rock` matches "Today's Indie Rock" without needing the curly quote.

If the playlist isn't found on the first attempt (e.g., subscription playlists may not be available immediately after wake), the script retries up to 5 times at 15-second intervals.

## Changing the time (or anything else)

1. Edit `~/Scripts/morning-shuffle.conf`
2. Re-run the installer:

```bash
~/Scripts/morning-shuffle-install.sh
```

The installer handles unloading the old schedule, generating a new plist, and updating pmset.

## Troubleshooting

**Check the log:**

```bash
cat ~/.morning-shuffle.log
```

**Check the current flag value:**

```bash
cat ~/Library/Mobile\ Documents/com~apple~CloudDocs/MorningShuffle/tomorrow.txt
```

**Test manually:**

```bash
~/Scripts/morning-shuffle.sh
```

**Verify launchd:**

```bash
launchctl list | grep morning-shuffle
```

**Verify scheduled wake:**

```bash
pmset -g sched
```

**Script runs late or doesn't fire on time:**
- Check system sleep timer: `pmset -g | grep ' sleep'`
- If it's very low (e.g. 1 minute), the Mac goes back to sleep before launchd fires
- Fix with: `sudo pmset -c sleep 15`

**Flag file reads as empty:**
- macOS may have evicted the iCloud file content — the script now uses `brctl download` to handle this
- Verify iCloud Drive is enabled and syncing on both devices
- Hardcode the full path in your conf (don't use `$HOME`)

**Playlist not found:**
- Run `osascript -e 'tell application "Music" to get name of every playlist'` to see all playlists
- For subscription playlists: `osascript -e 'tell application "Music" to get name of every subscription playlist'`
- Check for Unicode issues: pipe the above through `cat -v`
- Make sure your `PLAYLIST_MATCH` keywords are specific enough to match exactly one playlist

**Audio not coming through speakers:**
- Confirm eqMac is set to launch at login
- Run `SwitchAudioSource -a` and verify the device name matches your config
- Check that eqMac's output is routed to your USB/dock speakers

## Uninstalling

```bash
launchctl unload ~/Library/LaunchAgents/com.user.morning-shuffle.plist
rm ~/Library/LaunchAgents/com.user.morning-shuffle.plist
rm ~/Scripts/morning-shuffle.conf ~/Scripts/morning-shuffle.sh ~/Scripts/morning-shuffle-install.sh
rm -rf ~/Library/Mobile\ Documents/com~apple~CloudDocs/MorningShuffle
sudo pmset repeat cancel
```
