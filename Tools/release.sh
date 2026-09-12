#!/bin/bash
# Publishes a new version of Tassel through the Homebrew tap: bumps the version,
# builds the disk image, releases it on desilva23/homebrew-tap and points the
# cask at it, then checks the public download matches what was built.
#
#   make release VERSION=0.1.2
#   make release VERSION=0.1.2 NOTES="Adds the vegvisir."
#
# Expects the tap checked out beside this repository (../homebrew-tap), or at
# TAP_DIR.

set -euo pipefail

version="${1:-}"
tap_repo="desilva23/homebrew-tap"
tap_dir="${TAP_DIR:-$(cd "$(dirname "$0")/../.." && pwd)/homebrew-tap}"
plist="Resources/Info.plist"
current=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$plist")

fail() { echo "release: $*" >&2; exit 1; }
next_patch() { IFS=. read -r major minor patch <<<"$current"; echo "$major.$minor.$((patch + 1))"; }

[[ -n "$version" && "$version" != "$current" ]] ||
    fail "give the new version, e.g. make release VERSION=$(next_patch) (now $current)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$version is not a version like 1.2.3"
[[ "$(git branch --show-current)" == main ]] || fail "releases are made from main"
[[ -z "$(git status --porcelain)" ]] || fail "commit or stash your changes first"
[[ -d "$tap_dir/.git" ]] || fail "no tap checkout at $tap_dir (set TAP_DIR)"
[[ -z "$(git -C "$tap_dir" status --porcelain)" ]] || fail "the tap checkout at $tap_dir has uncommitted changes"
if gh release view "tassel-$version" --repo "$tap_repo" >/dev/null 2>&1; then
    fail "tassel-$version is already released"
fi

git pull -q --ff-only
git -C "$tap_dir" pull -q --ff-only
make check

echo "==> Tassel $current -> $version"
# Put the version back if the build fails before it is committed.
trap 'git checkout -q -- "$plist"' ERR
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" \
    -c "Set :CFBundleVersion $((build + 1))" "$plist"
make dist
dmg=".build/Tassel-$version.dmg"
sha=$(shasum -a 256 "$dmg" | cut -d' ' -f1)
git add "$plist"
git commit -q -m "Version $version"
trap - ERR
git push -q

echo "==> Publishing the disk image"
gh release create "tassel-$version" "$dmg" --repo "$tap_repo" --title "Tassel $version" \
    --notes "${NOTES:-Tassel $version.}

Install with \`brew install desilva23/tap/tassel\`, or update with \`brew upgrade tassel\`."

echo "==> Pointing the cask at it"
cask="$tap_dir/Casks/tassel.rb"
sed -i '' -e "s/^  version \".*\"\$/  version \"$version\"/" \
    -e "s/^  sha256 \".*\"\$/  sha256 \"$sha\"/" "$cask"
git -C "$tap_dir" commit -q -m "Tassel $version" -- Casks/tassel.rb
git -C "$tap_dir" push -q

echo "==> Checking the public download"
url="https://github.com/$tap_repo/releases/download/tassel-$version/Tassel-$version.dmg"
published=$(curl -sfL "$url" | shasum -a 256 | cut -d' ' -f1)
[[ "$published" == "$sha" ]] || fail "the published download does not match the build"

echo "==> Released Tassel $version"
echo "    New installs:  brew install desilva23/tap/tassel"
echo "    Updates:       brew upgrade tassel"
