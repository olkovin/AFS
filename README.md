# Auto File Sorter (AFS)

A bash script that automatically organizes files into date-based folder structures. Originally migrated from PowerShell to support Linux environments.

## Features

- 📅 **Date-based organization** - Sorts files into Year/Month/Day folders
- 🌍 **Multi-language support** - English and Ukrainian interfaces
- 🔍 **Flexible filtering** - By file extension or regex patterns
- ⏰ **Automated scheduling** - Cron integration for hands-free operation
- 🧪 **Dry-run mode** - Preview changes before execution
- 📊 **Admin interface** - Interactive menu for configuration
- 📝 **Automatic logging** - Detailed logs with rotation

## Quick Start

```bash
# Clone and setup
git clone https://github.com/yourusername/auto-file-sorter.git
cd auto-file-sorter
chmod +x afs.sh

# Run admin interface
./afs.sh --admin

# Configure and test
./afs.sh --dry-run  # Preview what will happen
./afs.sh            # Run sorting
```

## Installation

### 1. Prerequisites

```bash
# Debian/Ubuntu
apt update
apt install cron

# For network shares (optional)
apt install nfs-common    # For NFS
apt install cifs-utils    # For SMB/CIFS
```

### 2. Basic Setup

```bash
# Create working directory
mkdir -p /opt/autofilesorter
cd /opt/autofilesorter

# Copy script
cp afs.sh /opt/autofilesorter/
chmod +x afs.sh

# Generate config
./afs.sh --admin
# Select option 4 to generate config
```

### 3. Configure

Edit `config.ini`:

```ini
# Key settings
script_processing_lang=EN              # Interface language (EN/UA)
search_filter_type=extension           # Filter type
search_filter=jpg                      # File extension to sort
src_path=/path/to/source              # Source directory
dst_path=/path/to/destination         # Destination directory
destination_naming_pattern=yyyy.MM.dd  # Folder structure
interval=repetitive                    # Scheduling mode
repetitive_interval=3600              # Run every hour (seconds)
```

## Usage

### Command Line Options

```bash
./afs.sh              # Run based on config settings
./afs.sh --admin      # Open admin menu
./afs.sh --dry-run    # Preview without moving files
./afs.sh --cron       # Force run (for scheduler)
./afs.sh --help       # Show help
```

### Admin Menu Features

1. **Cron Management** - Enable/disable automatic scheduling
2. **Status Check** - View current cron configuration
3. **Test Files** - Generate sample files for testing
4. **Configuration** - Edit settings interactively
5. **Manual Run** - Execute sorting immediately
6. **Dry Run** - Preview changes safely

### Date Detection Priority

1. **Filename pattern** - `_YYMMDD` format (e.g., `photo_240915_001.jpg`)
2. **File creation time** - If supported by filesystem
3. **File modification time** - Fallback option

### Folder Structure Examples

With `destination_naming_pattern=yyyy.month.dd` and `script_processing_lang=EN`:
```
/destination/
├── 2024/
│   ├── October/
│   │   └── 15/
│   │       └── document_241015.jpg
│   └── September/
│       └── 10/
│           └── image_240910.jpg
└── 2025/
    └── March/
        └── 20/
            └── photo_250320.jpg
```

## Scheduling

### Using Cron

```bash
# Add to crontab
crontab -e

# Examples:
0 * * * * /opt/autofilesorter/afs.sh --cron      # Every hour
*/30 * * * * /opt/autofilesorter/afs.sh --cron   # Every 30 minutes
0 2 * * * /opt/autofilesorter/afs.sh --cron      # Daily at 2 AM
```

### Network Shares

For NFS mounts, add to `/etc/fstab`:
```
server:/share/path /mnt/sorting_point nfs defaults,_netdev 0 0
```

## Configuration Reference

| Parameter | Values | Description |
|-----------|--------|-------------|
| `script_processing_lang` | EN, UA | Interface language |
| `search_filter_type` | extension, name-regex | Filter method |
| `search_filter` | jpg, pdf, etc. | File pattern |
| `interval` | once, repetitive, on-boot | Scheduling mode |
| `repetitive_interval` | seconds | Frequency (min: 60) |
| `destination_naming_pattern` | yyyy.MM.dd | Folder format |
| `debug` | true, false | Verbose logging |
| `admin_mode` | true, false | Start in menu |

## Logs

Logs are stored in `./script_logs/` with daily rotation:
```bash
tail -f script_logs/log_$(date +%d-%m-%Y).txt
```

## Troubleshooting

### Files not being processed
- Check file permissions: `ls -la /source/path/`
- Verify filter settings in config.ini
- Run with debug mode: Set `debug=true`

### Cron not working
- Check cron syntax: `crontab -l`
- Verify script uses `--cron` flag
- Check logs: `grep CRON /var/log/syslog`

### Permission denied
```bash
chmod +x afs.sh
chown -R user:group /destination/path
```

## License

**Copyright (c) 2025 olkovin. All Rights Reserved.**

This software is proprietary and confidential.

### You MAY:
- ✅ Use the code for personal, non-commercial purposes
- ✅ Study the code for educational purposes

### You MAY NOT:
- ❌ Copy, redistribute, or share the code
- ❌ Modify or create derivative works
- ❌ Use for commercial purposes
- ❌ Resell or sublicense

For commercial licensing or special permissions, contact: **t.me/olekovin**

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.

## Contributing

This is a closed-source project. Issues and suggestions are welcome, but pull requests will not be accepted without prior agreement.

## Credits

Created by the brave and clever Claude Opus 4.1 and the persistent @olkovin who loves solving problems 🚀

Originally developed for organizing scanned documents from network scanners.