cask "gitbar" do
  version "1.0.0"
  sha256 "8e11dc41468418804e4e94fc3103db5353beb5c262da957651f591fc5e580afa"

  url "https://github.com/burhanusman/gitbar/releases/download/v#{version}/GitBar-v#{version}.dmg"
  name "GitBar"
  desc "Menubar app displaying git status for Claude Code and Codex projects"
  homepage "https://github.com/burhanusman/gitbar"

  livecheck do
    url "https://github.com/burhanusman/gitbar/releases/latest/download/appcast.xml"
    strategy :sparkle
  end

  auto_updates true

  app "GitBar.app"

  zap trash: [
    "~/Library/Application Support/com.gitbar.app",
    "~/Library/Caches/com.gitbar.app",
    "~/Library/Preferences/com.gitbar.app.plist",
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
