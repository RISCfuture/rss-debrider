# ``rss_debrider/OnePassword``

Integration with 1Password CLI for secure credential retrieval.

## Overview

The OnePassword module provides integration with the 1Password command-line
interface (`op`) for securely retrieving usernames, passwords, and one-time
passwords from your 1Password vault.

This allows you to store your Synology NAS credentials in 1Password instead of
passing them as command-line arguments, which is more secure as the credentials
won't appear in your shell history.

## Prerequisites

To use 1Password integration:

1. Install the [1Password CLI](https://developer.1password.com/docs/cli/)
2. Sign in to your 1Password account using `op signin`
3. Create a Login item in 1Password with your Synology credentials
4. Pass the item's ID to rss-debrider using the `--1pw-id` option

## Topics

### Client

- ``Client``
