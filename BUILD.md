# Build & Deploy Activity Tracker

## Processo completo di build

Ogni volta che si modifica il codice, bisogna CANCELLARE il bundle e RICREARLO da zero.
macOS cacha il bundle e non rileva le modifiche se si sovrascrive solo il binario.

### Metodo rapido

```bash
./start.sh
```

Lo script esegue tutti i passaggi automaticamente.

### Metodo manuale

#### 1. Chiudi l'app
```bash
killall ActivityTracker 2>/dev/null; sleep 1
```

#### 2. Cancella TUTTO il bundle
```bash
rm -rf ActivityTracker.app
```

#### 3. Build
```bash
swift build
```

#### 4. Ricrea il bundle da zero
```bash
mkdir -p ActivityTracker.app/Contents/MacOS
mkdir -p ActivityTracker.app/Contents/Resources
cp .build/debug/ActivityTracker ActivityTracker.app/Contents/MacOS/ActivityTracker
cp AppIcon.icns ActivityTracker.app/Contents/Resources/AppIcon.icns
chmod +x ActivityTracker.app/Contents/MacOS/ActivityTracker
```

#### 5. Ricrea Info.plist
```bash
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
```

#### 6. Avvia
```bash
open ActivityTracker.app
```

#### 7. Permessi Accessibility
Dopo aver ricreato il bundle, macOS potrebbe non riconoscere i permessi precedenti.
Aprire le impostazioni e riaggiungere l'app:
```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```
Aggiungere `ActivityTracker.app` dalla cartella del progetto.

## Note importanti
- NON basta copiare il binario dentro il bundle esistente — macOS cacha il bundle
- Bisogna SEMPRE cancellare `ActivityTracker.app` e ricrearlo da zero
- I permessi Accessibility vanno riconcessi dopo ogni ricreazione del bundle
- Il database SQLite in `~/Library/Application Support/ActivityTracker/` NON viene toccato dalla rebuild
