cask "tassel" do
  version "0.1.3"
  sha256 "fe31cbff59feac42ddda57918c9cd5473b5195a4684a4be019159c586a4f212e"

  url "https://github.com/desilva23/Tassel/releases/download/v#{version}/Tassel-#{version}.dmg"
  name "Tassel"
  desc "Lucky charm that hangs from the menu bar on a swinging cord"
  homepage "https://github.com/desilva23/Tassel"

  depends_on macos: :sonoma

  app "Tassel.app"

  # Tassel is not notarized, so macOS would refuse the first open and send the
  # user to System Settings. Clearing the download flag lets it open directly.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Tassel.app"]
  end

  uninstall quit: "com.example.tassel"

  zap trash: "~/Library/Preferences/com.example.tassel.plist"
end
