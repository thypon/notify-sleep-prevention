# Sleep Prevention Monitor

A Ruby application that monitors macOS for applications preventing sleep and sends persistent notifications.

## Features

- Monitors system for apps preventing sleep using `pmset -g assertions`
- Sends persistent macOS notifications when apps are detected
- Automatically removes notifications when no apps are preventing sleep
- Updates notifications when the list of preventing apps changes

## Requirements

- macOS
- Ruby
- terminal-notifier (installed via Homebrew)

## Installation

1. Install terminal-notifier:
   ```bash
   brew install terminal-notifier
   ```

2. Make the script executable:
   ```bash
   chmod +x sleep_monitor.rb
   ```

## Usage

Run the monitor:
```bash
ruby sleep_monitor.rb
```

The script will:
- Check for sleep-preventing apps every 5 seconds
- Show notifications for apps like `caffeinate`, `coreaudiod`, media players, etc.
- Automatically remove notifications when all preventing apps stop
- Skip system processes like `powerd`

To stop the monitor, press `Ctrl+C`.

## Running as Background Service

To run continuously in the background:
```bash
ruby sleep_monitor.rb &
```

## Notification Details

- **Title**: "Sleep Prevention Alert"
- **Subtitle**: Shows count of preventing apps
- **Message**: Lists each preventing application
- Notifications are grouped and replaced when the app list changes
- Notifications are automatically removed when no apps are preventing sleep