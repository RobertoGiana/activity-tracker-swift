# Activity Tracker - SwiftUI Native

App nativa macOS per tracciare automaticamente le attività dell'utente, classificandole come lavoro o svago.

## 🚀 Caratteristiche

- ✅ **100% Nativo macOS** - SwiftUI + AppKit
- ✅ **Tracciamento automatico** delle app aperte
- ✅ **Calendario mensile** con statistiche
- ✅ **Classificazione** attività (lavoro/svago/non tracciare)
- ✅ **Pattern matching** per categorizzazione automatica
- ✅ **Menu Bar App** - rimane attiva in background
- ✅ **Database SQLite** locale (privacy first)
- ✅ **Compatibile macOS 13+** (incluso macOS 26 beta)

## 📋 Requisiti

- macOS 13.0+ (Ventura o superiore)
- Xcode 15+ (per sviluppo)
- Swift 5.9+

## 🛠️ Build & Run

### Con Swift Package Manager (raccomandato)

```bash
cd activity-tracker-swift

# Build
swift build

# Run
swift run
```

### Con Xcode

```bash
# Apri in Xcode
open Package.swift

# Oppure crea progetto Xcode
swift package generate-xcodeproj
open ActivityTracker.xcodeproj
```

### Build Release

```bash
swift build -c release

# L'eseguibile sarà in:
# .build/release/ActivityTracker
```

## 📱 Primo Avvio

1. **Avvia l'app**
2. **Concedi permessi Accessibility**
   - Vai in: Preferenze di Sistema > Privacy e Sicurezza > Accessibilità
   - Abilita "ActivityTracker"
3. **L'app inizierà a tracciare** le tue attività automaticamente

## 🎯 Funzionalità

### Dashboard
- Statistiche giornaliere (lavoro/svago)
- Attività corrente in tempo reale
- Lista delle attività del giorno

### Calendario
- Visualizzazione mensile
- Indicatori colorati per lavoro/svago
- Dettagli giornalieri al click

### Classificazione
- Click su un'attività per classificarla
- Categorie: Lavoro, Svago, Non tracciare
- Nome generalizzato opzionale (es. "amazon", "github")

### Pattern Matching
- Classificazione automatica basata su pattern
- Pattern predefiniti per app comuni
- Possibilità di aggiungere pattern personalizzati

## 📁 Struttura Progetto

```
activity-tracker-swift/
├── Package.swift           # Configurazione Swift Package
├── README.md
└── Sources/
    ├── App/
    │   └── ActivityTrackerApp.swift   # Entry point + Menu Bar
    ├── Models/
    │   └── Activity.swift             # Modelli dati
    ├── Views/
    │   ├── ContentView.swift          # Layout principale
    │   ├── DashboardView.swift        # Dashboard
    │   ├── CalendarView.swift         # Calendario
    │   ├── PatternListView.swift      # Gestione pattern
    │   ├── SettingsView.swift         # Impostazioni
    │   └── Components/
    │       └── ClassificationSheet.swift
    ├── Services/
    │   ├── DatabaseService.swift      # SQLite
    │   ├── WindowTracker.swift        # Accessibility API
    │   ├── ActivityMonitor.swift      # Monitoraggio
    │   ├── ActivityStore.swift        # State management
    │   └── PermissionsService.swift   # Permessi macOS
    └── Utils/
```

## 🔐 Permessi Richiesti

- **Accessibility**: Per leggere il titolo delle finestre attive

## 💾 Dove Vengono Salvati i Dati

```
~/Library/Application Support/ActivityTracker/activity-tracker.db
```

## 🆚 Differenze da Versione Electron

| Aspetto | Electron | SwiftUI |
|---------|----------|---------|
| Dimensione | ~150MB | ~5MB |
| RAM | ~200MB | ~30MB |
| CPU | Alta | Bassa |
| Compatibilità macOS 26 | ❌ Problematica | ✅ Perfetta |
| Firma/Notarizzazione | ⚠️ Complessa | ✅ Semplice |
| Startup | Lento | Immediato |

## 📝 Note

- L'app rimane attiva nella menu bar anche quando chiudi la finestra
- Il monitoraggio avviene ogni 2 secondi
- Le attività idle (>5 minuti) vengono chiuse automaticamente
- Tutti i dati sono salvati localmente (nessun cloud)

## 🐛 Troubleshooting

### L'app non traccia le finestre
1. Verifica i permessi Accessibility in Preferenze di Sistema
2. Rimuovi e riaggiungi l'app dalla lista
3. Riavvia l'app

### Database non si crea
1. Verifica permessi della cartella Application Support
2. Controlla i log nella console

### L'app non si avvia
```bash
# Verifica build
swift build 2>&1

# Controlla errori
```

## 📜 Licenza

MIT

---

**Versione**: 1.0.0  
**Build**: SwiftUI Native  
**Compatibilità**: macOS 13.0+




