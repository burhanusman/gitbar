cask "gitbar" do
  version "1.0.0"
  sha256 :no_check # Will be updated with actual SHA256 after first release

  url "https://github.com/yourusername/gitbar/releases/download/v#{version}/GitBar-v#{version}.dmg"
  name "GitBar"
  desc "Menubar app displaying git status for Claude Code and Codex projects"
  homepage "https://github.com/yourusername/gitbar"

  livecheck do
    url "https://github.com/yourusername/gitbar/releases/latest/download/appcast.xml"
    strategy :sparkle
  end

  auto_updates true

  app "GitBar.app"

  zap trash: [
    "~/Library/Application Support/com.yourcompany.GitBar",
    "~/Library/Caches/com.yourcompany.GitBar",
    "~/Library/Preferences/com.yourcompany.GitBar.plist",
  ]

  caveats <<~EOS
    GitBar is a menubar-only application with no Dock icon.

    After installation:
    1. Launch GitBar from Applications or Spotlight
    2. Look for the git branch icon in your menubar (top-right)
    3. Click the icon to view your projects

    The app runs in the background and can be accessed from the menubar.
  EOS
end
