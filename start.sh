#!/bin/bash
# Script per buildare, ricreare il bundle e avviare Activity Tracker
# Uso: ./start.sh

cd "$(dirname "$0")"

echo "🚀 Activity Tracker - SwiftUI Native"
echo ""

# 1. Chiudi se già in esecuzione
if pgrep -x "ActivityTracker" > /dev/null; then
    echo "⚠️ Activity Tracker già in esecuzione, chiudo..."
    pkill -x "ActivityTracker"
    sleep 1
fi

# 2. Cancella il bundle vecchio
echo "🗑️ Rimozione bundle vecchio..."
rm -rf ActivityTracker.app

# 3. Build
echo "📦 Build in corso..."
swift build
if [ $? -ne 0 ]; then
    echo "❌ Errore durante la build"
    exit 1
fi

# 4. Ricrea il bundle da zero
echo "📋 Creazione bundle .app..."
mkdir -p ActivityTracker.app/Contents/MacOS
mkdir -p ActivityTracker.app/Contents/Resources

cp .build/debug/ActivityTracker ActivityTracker.app/Contents/MacOS/ActivityTracker
cp AppIcon.icns ActivityTracker.app/Contents/Resources/AppIcon.icns
chmod +x ActivityTracker.app/Contents/MacOS/ActivityTracker

cat > ActivityTracker.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ActivityTracker</string>
    <key>CFBundleIdentifier</key>
    <string>com.robertogiana.ActivityTracker</string>
    <key>CFBundleName</key>
    <string>Activity Tracker</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 5. Avvia
echo "✅ Avvio Activity Tracker..."
open ActivityTracker.app

echo ""
echo "📋 L'app è stata avviata!"
echo "   • Cerca l'icona nella menu bar (orologio)"
echo "   • Concedi permessi Accessibility se richiesto"
echo ""
echo "Per chiudere: pkill ActivityTracker"
