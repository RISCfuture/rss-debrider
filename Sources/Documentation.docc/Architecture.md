# Architecture

Understand how rss-debrider orchestrates downloads through multiple services.

## Overview

rss-debrider automates the process of downloading media from RSS feeds by
coordinating between three main components:

1. **RSS Feed Provider** (e.g., ShowRSS) - Provides magnet links for content
2. **Real-Debrid** - Downloads torrents to their servers and provides direct links
3. **Synology NAS** - Downloads the files to your local storage

The tool also optionally integrates with **1Password** to securely retrieve
Synology credentials.

## Process Flow

The following diagram illustrates the complete download workflow:

![Architecture diagram showing the flow from RSS feed through Real-Debrid to Synology NAS](architecture.png)

### Step-by-Step Breakdown

1. **Parse RSS Feed**: The ``RSS/Client`` downloads and parses the RSS feed,
   extracting magnet links from `<link>` or `<enclosure>` elements.

2. **Filter Downloaded Links**: Previously downloaded links are filtered out
   by checking against the `.rss-client-history` file.

3. **Submit Magnet**: New magnet links are submitted to Real-Debrid using
   ``RealDebrid/Client/addMagnet(_:)``.

4. **Poll Status**: The tool polls ``RealDebrid/Client/torrentInfo(id:)``
   to monitor the torrent's progress.

5. **Select File**: When the torrent reaches the
   ``RealDebrid/Response/TorrentInfo/Status-swift.enum/awaitingFileSelection``
   status, the largest file is automatically selected using
   ``RealDebrid/Client/selectFiles(torrentID:files:)``.

6. **Wait for Download**: The tool continues polling until the torrent
   status changes to
   ``RealDebrid/Response/TorrentInfo/Status-swift.enum/downloaded``.

7. **Unrestrict Link**: The restricted download link is converted to a
   direct URL using ``RealDebrid/Client/unrestrictedLink(url:)``.

8. **Create Task**: The direct URL is sent to the Synology NAS using
   ``Synology/Client/createTask(urls:)`` to begin the local download.

9. **Mark as Downloaded**: The magnet link is recorded in the history file
   to prevent duplicate downloads.

## Client Architecture

rss-debrider uses the actor model for all API clients, ensuring thread-safe
concurrent access:

- ``RSS/Client`` - Parses RSS feeds and manages download history
- ``RealDebrid/Client`` - Communicates with the Real-Debrid REST API
- ``Synology/Client`` - Communicates with the Synology DownloadStation API
- ``OnePassword/Client`` - Retrieves credentials from 1Password CLI

All API calls are asynchronous, and multiple magnet links are processed
concurrently using Swift's structured concurrency.

## Error Handling

Each client has dedicated error types with localized descriptions and
recovery suggestions:

- ``RSSErrors`` - RSS feed parsing and download errors
- ``RealDebridErrors`` - Real-Debrid API errors
- ``SynologyErrors`` - Synology API and authentication errors
- ``Errors`` - General errors

Errors are logged with context and metadata, and the tool continues
processing remaining links even if individual downloads fail.
