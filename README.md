# RSS-Debrider

RSS-Debrider is a macOS executable that 1) downloads a list of magnet links from
an RSS feed (such as the one provided by [ShowRSS](http://showrss.info/)), 2)
submits the links to Real-Debrid for remote download, and 3) pushes the debrided
to a Synology NAS for download to your NAS storage. RSS-Debrider is written in
Swift and intended to be run as a cron job using a launch agent.

## Usage

```
USAGE: rss-debrider --api-key <api-key> [--hostname <hostname>] [--port <port>] [--username <username>] [--password <password>] [--1pw-id <1pw-id>] [--debug] <url>

ARGUMENTS:
  <url>                   The URL of the RSS feed of magnet links.

OPTIONS:
  -k, --api-key <api-key> The API key for Real-Debrid.
  -h, --hostname <hostname>
                          The hostname of the Synology NAS.
  -p, --port <port>       The port of the Synology NAS. (default: 5000)
  -u, --username <username>
                          The username of the Synology NAS.
  -P, --password <password>
                          The password of the Synology NAS.
  -i, --1pw-id <1pw-id>   The ID of the 1Password item containing the information for the Synology account.
  -d, --debug             Enable debug-level logging.
  -h, --help              Show help information.```

## Prerequisites

To use RSS-Debrider, you must have the following:

* A hosted RSS feed of magnet links you wish to download, such as from ShowRSS.
* A paid, premium Real-Debrid account in good standing.
* A Real-Debrid API key, which you can retrieve from https://real-debrid.com/apitoken
* A Synology NAS running DSM 7 or later, with Download Station installed.
* The username and password to a Synology user on that NAS, with permissions to
  submit files to Download Station via the API.
* A computer running macOS 14 or later that can periodically run the
  `rss-debrider` binary.
* If your macOS machine is on a different network than your Synology NAS, you
  will need to configure your router and firewall settings so that you can
  access the Synology API (over port 5000, typically) remotely.

## Installation

Run `swift build -c release` to build the `rss-debrider` binary. Copy the binary
somewhere you can access, such as your `~/Applications` directory.

Create a LaunchAgent plist file (see
https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
and place it in `~/Library/LaunchAgents`. The plist file should look something
like this:

``` xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.yourdomain.rss-debrider</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/rss-debrider</string>
        <string>-k</string>
        <string>YOUR_REAL_DEBRID_API_KEY</string>
        <string>-h</string>
        <string>YOUR_SYNOLOGY_HOSTNAME</string>
        <string>-u</string>
        <string>YOUR_SYNOLOGY_USERNAME</string>
        <string>-P</string>
        <string>YOUR_SYNOLOGY_PASSWORD</string>
        <string>YOUR_RSS_URL</string>
    </array>
    <key>StandardErrorPath</key>
    <string>/path/to/some/logfolder/rss-debrider.error.log</string>
    <key>StandardOutPath</key>
    <string>/path/to/some/logfolder/rss-debrider.log</string>
    <key>WorkingDirectory</key>
    <string>YOUR_HOME</string>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>0</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>

</dict>
</plist>
```

Carefully review the plist file above and customize it to your needs. Pay close
attention to the program arguments passed to `rss-debrider`, and also note that:

* `rss-debrider` will store an `.rss-client-history` file in the working
  directory (`WorkingDirectory` key), which is used to keep track of the
  magnet links that have already been downloaded.
* You can include `-d` as an argument to increase the verbosity of logging to
  `StandardOutPath`, to help troubleshoot problems.
* Special characters in URLs will need to be escaped. When in doubt, create the
  plist using Xcode to ensure proper formatting.

Use `launchctl load -w ~/Library/LaunchAgents/com.yourdomain.rss-debrider.plist`
to begin periodic polling of your RSS feed. `launchctl unload` will temporarily
stop your launch agent.

### Two-Factor Authentication

If your Synology account requires two-factor authentication with an OTP token,
you must have that token stored in a 1Password account. `rss-debrider` will use
the ID of that 1Password item with the `op` CLI tool, instead of the
`--username` and `--password` options:

``` sh
rss-debrider --api-key <api-key> --hostname <hostname> --port <port> --1pw-id <1pw-id> <url>
``` 

To find the ID of the 1Password item, use `op item list`.

Note that using 1Password will not work well with Launch Agents, since 1Password
will prompt you for your password or Touch ID.

## Source Documentation

Online API documentation and tutorials are available at
https://riscfuture.github.io/rss-debrider/documentation/rss-debrider/

DocC documentation is available, including tutorials and API documentation. For
Xcode documentation, you can run

```sh
swift package generate-documentation --target rss-debrider
```

to generate a docarchive at
`.build/plugins/Swift-DocC/outputs/SwiftMETAR.doccarchive`. You can open this
docarchive file in Xcode for browseable API documentation. Or, within Xcode,
open the SwiftMETAR package in Xcode and choose **Build Documentation** from the
**Product** menu.
