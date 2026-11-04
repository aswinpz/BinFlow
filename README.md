# BinFlow – iOS bin find & allocate

SwiftUI + SwiftData, iOS 17+. Tabs: Find, Allocate, Bins, Activity.

## Get the IPA (no Mac needed)
1. Create a GitHub repo, upload everything in this folder (keep `.github/`).
2. Actions tab → "Build IPA" → Run workflow. Download artifact `BinFlow-ipa` → unzip → `BinFlow.ipa`.

## Install with Sideloadly
1. Connect iPhone, trust the computer. Enable Developer Mode (Settings → Privacy & Security).
2. Drag `BinFlow.ipa` into Sideloadly, enter your Apple ID, click Start.
3. On iPhone: Settings → General → VPN & Device Management → trust your Apple ID.
4. Free Apple IDs expire after 7 days: re-sideload (data is kept if you install over the top).

## Mac option
`brew install xcodegen && xcodegen generate && open BinFlow.xcodeproj`
