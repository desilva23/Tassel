cask "tassel" do
  version "0.1.2"
  sha256 "1d6771b8920cd593683d6b6a42de908919b5708ffb8053a82fcd13ef80d6eeac"

  url "https://github.com/desilva23/Tassel/releases/download/v#{version}/Tassel-#{version}.dmg"
  name "Tassel"
  desc "Lucky charm that hangs from the menu bar on a swinging cord"
  homepage "https://github.com/desilva23/Tassel"

  depends_on macos: :sonoma

  app "Tassel.app"

  # Tassel is not notarized, so macOS would refuse the first open and send the
  # user to System Settings. Clearing the download flag lets it open directly.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Tassel.app"]
  end

  uninstall quit: "com.example.tassel"

  zap trash: "~/Library/Preferences/com.example.tassel.plist"
end
