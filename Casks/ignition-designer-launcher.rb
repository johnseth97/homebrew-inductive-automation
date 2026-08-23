cask "ignition-designer-launcher" do
  version "8.3.8"
  sha256 "9cd652c0ea059e3944252eb75b5362f9154554c49c4be645926da499ac289b1d"

  url "https://releases.inductiveautomation.com/release/#{version}/20260714-1000/designerlauncher.dmg",
      referer: "https://inductiveautomation.com/downloads/ignition/#{version}"
  name "Ignition Designer Launcher"
  desc "Launcher for Inductive Automation Ignition Designer"
  homepage "https://inductiveautomation.com/ignition/designer/"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Designer Launcher.app"

  livecheck do
    url "https://inductiveautomation.com/downloads/ignition"
    regex(/"8\.3".*?"version":\s*"(8\.3\.\d+)".*?"state":\s*"STABLE"/im)
  end

  zap trash: [
    "~/Library/Application Support/Inductive Automation",
    "~/.ignition/clientlauncher-data",
  ]
end
