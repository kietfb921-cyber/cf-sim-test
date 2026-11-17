#!/bin/bash
# Build the harness + the REAL diag.m for the iOS simulator, run it and print
# UIKit's own verdict on touch routing. Needs macOS with Xcode.
set -euo pipefail
BID="com.cf.harness"
SDK=$(xcrun -sdk iphonesimulator -show-sdk-path)
mkdir -p build/Harness.app/Frameworks

echo "== compiling diag.m (the shipped source) for the simulator"
clang -target arm64-apple-ios15.0-simulator -isysroot "$SDK" -dynamiclib -fobjc-exceptions -I. \
  -O2 diag.m -o build/Harness.app/Frameworks/libdiag.dylib \
  -Wl,-install_name,@executable_path/Frameworks/libdiag.dylib \
  -framework Foundation -framework UIKit

echo "== compiling the harness app"
clang -target arm64-apple-ios15.0-simulator -isysroot "$SDK" -fobjc-arc -O2 \
  harness/main.m harness/stubs.m -o build/Harness.app/Harness \
  -framework UIKit -framework Foundation \
  -L build/Harness.app/Frameworks -ldiag

cat > build/Harness.app/Info.plist <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>HARNESS_EXE</string>
  <key>CFBundleIdentifier</key><string>com.cf.harness</string>
  <key>CFBundleName</key><string>Har</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>UIStatusBarHidden</key><true/>
</dict></plist>
PL
python3 -c "p='build/Harness.app/Info.plist'; s=open(p).read().replace('HARNESS_EXE','Harness'); open(p,'w').write(s)"

echo "== booting simulator"
xcrun simctl shutdown all >/dev/null 2>&1 || true
xcrun simctl boot "iPhone 15" 2>/dev/null || xcrun simctl boot "iPhone 14" 2>/dev/null || true
sleep 20

echo "== installing and launching"
xcrun simctl install booted build/Harness.app
xcrun simctl launch booted $BID
sleep 14

echo "== harness log (UIKit hit-test verdict):"
CONT=$(xcrun simctl get_app_container booted $BID data)
cat "$CONT/Documents/harness.log" || echo "(no log produced)"
echo
echo "== diag.m log:"
cat "$CONT/Documents/cfdiag"*.log 2>/dev/null || true
