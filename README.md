# Morning Playlist Shuffle — Setup Guide

## What this does

Every weekday morning, your Mac will:

1. Wake from sleep (via `pmset`)
2. Check an iCloud Drive flag file to see if you said "yes" or "skip" the night before
3. If enabled: set audio output to eqMac and shuffle/play your chosen playlist

Each evening, your iPhone prompts you to decide whether music plays the next morning.

## Files

| File | Purpose |
|------|---------|
| `morning-shuffle.conf` | All settings — playlist, time, device, volume, flag file path |
| `morning-shuffle.sh` | Main script (reads conf, checks flag, plays music) |
| `morning-shuffle-install.sh` | Generates launchd plist and pmset schedule from conf |

## Prerequisites

```bash
brew install switchaudio-osx
```

Find your eqMac device name:

```bash
SwitchAudioSource -a
```

## Mac Setup

### 1. Copy files to a permanent location

```bash
mkdir -p ~/Scripts
cp morning-shuffle.conf morning-shuffle.sh morning-shuffle-install.sh ~/Scripts/
chmod +x ~/Scripts/morning-shuffle.sh ~/Scripts/morning-shuffle-install.sh
```

### 2. Edit the config

Open `~/Scripts/morning-shuffle.conf` and set:

- `PLAYLIST_NAME` — exact name of your Apple Music playlist
- `EQMAC_DEVICE` — device name from `SwitchAudioSource -a`
- `PLAY_HOUR` and `PLAY_MINUTE` — when to start playback (default: 8:30)
- `VOLUME` — playback volume, 0–100 (default: 40)

### 3. Create the iCloud Drive directory

```bash
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/MorningShuffle
```

### 4. Grant Automation permissions

Run the script once manually while your Mac is **unlocked**:

```bash
~/Scripts/morning-shuffle.sh
```

macOS will prompt you to allow Terminal to control Music.app. Click **OK**.

### 5. Run the installer

```bash
~/Scripts/morning-shuffle-install.sh
```

## iPhone Setup (Shortcuts)

Create a shortcut on your iPhone and set it to run as a nightly automation.

### Create the Shortcut

1. Open the **Shortcuts** app on your iPhone
2. Tap **+** to create a new shortcut, name it **"Morning Music Prompt"**
3. Add these actions in order:

   **a. Choose from Menu**
   - Prompt: `Play morning music tomorrow?`
   - Options: `Yes` and `Skip`

   **b. Under the "Yes" branch:**
   - Add action: **Save File**
   - In the text/content field, type: `play`
   - Save to: `iCloud Drive > MorningShuffle`
   - Filename: `tomorrow.txt`
   - Toggle **Ask Where to Save** OFF
   - Toggle **Overwrite If File Exists** ON

   **c. Under the "Skip" branch:**
   - Add action: **Save File**
   - In the text/content field, type: `skip`
   - Save to: `iCloud Drive > MorningShuffle`
   - Filename: `tomorrow.txt`
   - Toggle **Ask Where to Save** OFF
   - Toggle **Overwrite If File Exists** ON

More precisely, the shortcut flow is:

```
Menu: "Play morning music tomorrow?"
├── Yes
│   └── Save "play" to iCloud Drive/MorningShuffle/tomorrow.txt
└── Skip
    └── Save "skip" to iCloud Drive/MorningShuffle/tomorrow.txt
```

### Set Up the Automation

1. In Shortcuts, go to the **Automation** tab
2. Tap **+** → **Time of Day**
3. Set time to something like **9:00 PM** (or whenever works for you)
4. Set **Repeat** to **Weekly**, select **Mon, Tue, Wed, Thu, Sun**
   (Sun night covers Monday morning; Mon–Thu nights cover Tue–Fri mornings)
5. Set **Run Immediately** to OFF so it notifies you instead of running silently
6. Select the **"Morning Music Prompt"** shortcut

That's it — each weekday evening you'll get a notification, tap it, and choose Yes or Skip.

## How the flag works

- If the flag file says `play` or `yes` → music plays
- If the flag file says `skip` or `no` → script exits silently
- If the flag file doesn't exist (e.g., you forgot to respond) → **music does not play by default**

## Changing the time (or anything else)

1. Edit `~/Scripts/morning-shuffle.conf`
2. Re-run the installer:

```bash
~/Scripts/morning-shuffle-install.sh
```

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

**Flag file not syncing:**
- Make sure iCloud Drive is enabled on both devices
- Check that the MorningShuffle folder exists in iCloud Drive on both devices
- iCloud can take a few minutes to sync — the 5-minute gap between wake and play helps here

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
