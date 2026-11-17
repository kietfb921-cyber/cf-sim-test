#!/bin/bash
set -uo pipefail
BID="com.cf.harness"
SDK=$(xcrun -sdk iphonesimulator -show-sdk-path)
mkdir -p build/Harness.app/Frameworks

echo "== compile diag.m (shipped source) for the simulator"
clang -target arm64-apple-ios15.0-simulator -isysroot "$SDK" -dynamiclib -fobjc-exceptions -I. \
  -O2 diag.m -o build/Harness.app/Frameworks/libdiag.dylib \
  -Wl,-install_name,@executable_path/Frameworks/libdiag.dylib \
  -framework Foundation -framework UIKit || exit 1

echo "== compile harness"
clang -target arm64-apple-ios15.0-simulator -isysroot "$SDK" -fobjc-arc -O1 \
  harness/main.m harness/stubs.m -o build/Harness.app/Harness \
  -framework UIKit -framework Foundation \
  -L build/Harness.app/Frameworks -ldiag || exit 1

cat > build/Harness.app/Info.plist <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Harness</string>
  <key>CFBundleIdentifier</key><string>com.cf.harness</string>
  <key>CFBundleName</key><string>Harness</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSRequiresIPhoneOS</key><true/>
</dict></plist>
PL

echo "== pick a simulator"
DEV=$(xcrun simctl list devices available -j | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
for rt,devs in d.items():
    for x in devs:
        if 'iPhone' in x['name']:
            print(x['udid']); raise SystemExit
")
echo "device=$DEV"
xcrun simctl boot "$DEV" 2>/dev/null
sleep 25
xcrun simctl install "$DEV" build/Harness.app || exit 1
xcrun simctl launch "$DEV" $BID || exit 1
sleep 12
CONT=$(xcrun simctl get_app_container "$DEV" $BID data)
echo "== harness log:"
cat "$CONT/Documents/harness.log" 2>/dev/null || echo "(no harness log)"
echo "== diag log:"
cat "$CONT/Documents"/cfdiag* 2>/dev/null || true
