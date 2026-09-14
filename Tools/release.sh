#!/bin/bash
# Publishes a new version of Tassel: bumps the version, builds the disk image,
# points the Homebrew cask in Casks/tassel.rb at it, releases it on GitHub, and
# checks the public download matches what was built.
#
#   make release VERSION=0.1.3
#   make release VERSION=0.1.3 NOTES="Adds the hamsa."

set -euo pipefail

version="${1:-}"
repo="desilva23/Tassel"
plist="Resources/Info.plist"
cask="Casks/tassel.rb"
current=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$plist")

fail() { echo "release: $*" >&2; exit 1; }
next_patch() { IFS=. read -r major minor patch <<<"$current"; echo "$major.$minor.$((patch + 1))"; }

[[ -n "$version" && "$version" != "$current" ]] ||
    fail "give the new version, e.g. make release VERSION=$(next_patch) (now $current)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$version is not a version like 1.2.3"
[[ "$(git branch --show-current)" == main ]] || fail "releases are made from main"
[[ -z "$(git status --porcelain)" ]] || fail "commit or stash your changes first"
if gh release view "v$version" --repo "$repo" >/dev/null 2>&1; then
    fail "v$version is already released"
fi

git pull -q --ff-only
make check

echo "==> Tassel $current -> $version"
# Put everything back if the build fails before it is committed.
trap 'git checkout -q -- "$plist" "$cask"' ERR
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" \
    -c "Set :CFBundleVersion $((build + 1))" "$plist"
make dist
dmg=".build/Tassel-$version.dmg"
sha=$(shasum -a 256 "$dmg" | cut -d' ' -f1)
sed -i '' -e "s/^  version \".*\"\$/  version \"$version\"/" \
    -e "s/^  sha256 \".*\"\$/  sha256 \"$sha\"/" "$cask"
git add "$plist" "$cask"
git commit -q -m "Version $version"
trap - ERR
git push -q

echo "==> Publishing the disk image"
gh release create "v$version" "$dmg" --repo "$repo" --target "$(git rev-parse HEAD)" \
    --title "Tassel $version" --notes "${NOTES:-Tassel $version.}

Install with Homebrew:

\`\`\`
brew trust desilva23/tassel
brew tap desilva23/tassel https://github.com/desilva23/Tassel
brew install tassel
\`\`\`

Already installed? \`brew upgrade tassel\`."

echo "==> Checking the public download"
url="https://github.com/$repo/releases/download/v$version/Tassel-$version.dmg"
published=$(curl -sfL "$url" | shasum -a 256 | cut -d' ' -f1)
[[ "$published" == "$sha" ]] || fail "the published download does not match the build"

echo "==> Released Tassel $version"
echo "    Updates: brew upgrade tassel"
