#!/bin/bash
#
# Installs Tassel, a hand-drawn lucky charm for your menu bar.
#
#   curl -fsSL https://raw.githubusercontent.com/desilva23/Tassel/main/install.sh | bash
#
# It downloads the latest release, checks it against the checksum this
# repository publishes, copies the app to /Applications and opens it. Read it
# first if you like — that is the whole of it.

set -euo pipefail

repo="desilva23/Tassel"
app="Tassel.app"

say() { printf '\033[1m%s\033[0m\n' "$1"; }
fail() { printf '\033[31m%s\033[0m\n' "$1" >&2; exit 1; }

version=$(sw_vers -productVersion)
[ "${version%%.*}" -ge 14 ] || fail "Tassel needs macOS 14 Sonoma or newer. This Mac is on $version."

say "Finding the latest release…"
dmg_url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" |
    sed -n 's/.*"browser_download_url": *"\([^"]*\.dmg\)".*/\1/p' | head -1)
[ -n "$dmg_url" ] || fail "No download found. Get it from https://github.com/$repo/releases"

work=$(mktemp -d)
cleanup() {
    hdiutil detach "$work/mnt" -quiet >/dev/null 2>&1 || true
    rm -rf "$work"
}
trap cleanup EXIT

say "Downloading ${dmg_url##*/}…"
curl -fsSL "$dmg_url" -o "$work/Tassel.dmg"

# The cask in this repository carries the checksum for the current release, and
# `make release` writes both in one commit. Check it when the two agree on the
# version; a mismatch there means the release is newer than the cask, not that
# the download is bad.
cask=$(curl -fsSL "https://raw.githubusercontent.com/$repo/main/Casks/tassel.rb" || true)
cask_version=$(printf '%s' "$cask" | sed -n 's/.*version "\([^"]*\)".*/\1/p' | head -1)
expected=$(printf '%s' "$cask" | sed -n 's/.*sha256 "\([a-f0-9]*\)".*/\1/p' | head -1)
if [ -n "$expected" ] && [ "${dmg_url##*/}" = "Tassel-$cask_version.dmg" ]; then
    actual=$(shasum -a 256 "$work/Tassel.dmg" | cut -d' ' -f1)
    [ "$expected" = "$actual" ] || fail "That download does not match its published checksum. Nothing was installed."
    say "Checksum matches."
fi

destination="/Applications"
[ -w "$destination" ] || destination="$HOME/Applications"
mkdir -p "$destination"

if pgrep -x Tassel >/dev/null 2>&1; then
    say "Quitting the running copy…"
    osascript -e 'quit app "Tassel"' >/dev/null 2>&1 || true
    sleep 1
fi

mkdir -p "$work/mnt"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$work/mnt" "$work/Tassel.dmg"
rm -rf "${destination:?}/$app"
ditto "$work/mnt/$app" "$destination/$app"
hdiutil detach "$work/mnt" -quiet

# Tassel is signed but not notarized — there is no Apple Developer account
# behind a free app — so macOS would refuse the first open and send you to
# System Settings. Clearing the download flag is what the Homebrew cask does
# too, and it is the last step here.
xattr -dr com.apple.quarantine "$destination/$app" 2>/dev/null || true

say "Installed to $destination/$app"
open "$destination/$app"
