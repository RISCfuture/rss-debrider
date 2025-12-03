# ``RSS/Client``

A client for downloading and parsing RSS feeds containing magnet links.

## Overview

The RSS client downloads an RSS feed and extracts magnet links from it. It can
also track which links have already been downloaded using a history file.

The client supports RSS feeds where magnet links appear either in `<link>`
elements within `<item>` elements, or in `<enclosure>` elements with a `url`
attribute.

## Topics

### Creating a Client

- ``init(data:historyFileURL:)``
- ``init(feedURL:historyFileURL:)``

### Parsing Links

- ``links()``

### Download History

- ``undownloadedLinks(_:)``
- ``markAsDownloaded(link:)``
