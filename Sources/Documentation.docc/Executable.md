# ``rss_debrider/Executable``

The main command-line interface for rss-debrider.

## Overview

The `Executable` struct is the entry point for the rss-debrider command-line
tool. It parses command-line arguments, orchestrates the download workflow,
and handles user interaction for missing credentials.

For usage information, see <doc:Usage>.

## Command-Line Options

The executable accepts the following options:

| Option | Description |
|--------|-------------|
| `--api-key`, `-k` | The Real-Debrid API key (required) |
| `--hostname`, `-h` | The Synology NAS hostname |
| `--port`, `-p` | The Synology NAS port (default: 5000) |
| `--username`, `-u` | The Synology NAS username |
| `--password`, `-P` | The Synology NAS password |
| `--1pw-id`, `-i` | 1Password item ID for Synology credentials |
| `--debug`, `-d` | Enable debug logging |

## Arguments

| Argument | Description |
|----------|-------------|
| `url` | The URL of the RSS feed containing magnet links (required) |
