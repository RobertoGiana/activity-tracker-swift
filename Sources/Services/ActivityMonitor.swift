import Foundation
import Combine
import IOKit

/// Servizio per il monitoraggio automatico delle attività
class ActivityMonitor: ObservableObject {
    static let shared = ActivityMonitor()
    
    @Published var currentActivity: Activity?
    @Published var isMonitoring: Bool = false
    
    private var timer: Timer?
    private var lastWindowInfo: WindowInfo?
    private let pollInterval: TimeInterval = 2.0 // 2 secondi
    private let idleThreshold: TimeInterval = 5 * 60 // 5 minuti
    private let minActivityDurationToKeep: Int = 3 // Sotto i 3s = rumore, droppata alla chiusura
    
    /// Timestamp dell'ultima attività utente rilevata (cambio finestra o input)
    private var lastUserActivityTime: Date = Date()
    
    private let db = DatabaseService.shared
    private let windowTracker = WindowTracker.shared
    private let patternMatcher = PatternMatcher.shared
    
    private init() {}
    
    /// Avvia il monitoraggio delle attività
    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️ Monitoraggio già attivo")
            return
        }
        
        print("🚀 Avvio monitoraggio attività...")
        isMonitoring = true
        
        // Timer per polling
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkAndUpdateActivity()
        }
        
        // Prima verifica immediata
        checkAndUpdateActivity()
    }
    
    /// Ferma il monitoraggio delle attività
    func stopMonitoring() {
        print("⏹️ Stop monitoraggio attività")
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        
        // Chiudi attività corrente se presente
        closeCurrentActivity()
    }
    
    /// Controlla e aggiorna l'attività corrente
    private func checkAndUpdateActivity() {
        // Controlla idle di sistema (mouse/tastiera) via IOKit
        let systemIdleSeconds = getSystemIdleTime()
        
        guard let windowInfo = windowTracker.getActiveWindow() else {
            handleIdle()
            return
        }
        
        // Se il sistema è idle oltre la soglia, chiudi l'attività corrente
        if systemIdleSeconds > idleThreshold {
            if currentActivity != nil {
                closeCurrentActivity()
                lastWindowInfo = nil
            }
            return
        }
        
        // Aggiorna timestamp ultima attività utente
        lastUserActivityTime = Date()
        
        // Verifica se è cambiata l'attività
        if hasActivityChanged(windowInfo) {
            // Chiudi attività precedente
            closeCurrentActivity()
            
            // Crea nuova attività
            createNewActivity(from: windowInfo)
            lastWindowInfo = windowInfo
        } else if var activity = currentActivity {
            // Aggiorna durata attività corrente
            let now = Date()
            activity.durationSeconds = Int(now.timeIntervalSince(activity.startTime))
            activity.updatedAt = now

            db.updateActivity(activity)
            currentActivity = activity
        }
    }
    
    /// Verifica se l'attività è cambiata
    private func hasActivityChanged(_ windowInfo: WindowInfo) -> Bool {
        guard let last = lastWindowInfo else {
            return true
        }
        
        return last.appBundleId != windowInfo.appBundleId ||
               last.activityName != windowInfo.activityName
    }
    
    /// Crea una nuova attività
    private func createNewActivity(from windowInfo: WindowInfo) {
        // Applica pattern matching per determinare categoria e nome generalizzato
        let patternMatch = patternMatcher.match(
            appName: windowInfo.appName,
            appBundleId: windowInfo.appBundleId,
            activityName: windowInfo.activityName,
            windowTitle: windowInfo.windowTitle
        )
        
        let newActivity = Activity(
            appName: windowInfo.appName,
            appBundleId: windowInfo.appBundleId,
            windowTitle: windowInfo.windowTitle,
            activityName: windowInfo.activityName,
            generalizedName: patternMatch?.generalizedName,
            category: patternMatch?.category,
            startTime: Date(),
            durationSeconds: 0
        )
        
        if let activityId = db.insertActivity(newActivity) {
            currentActivity = db.getActivityById(activityId)
            
            // Notifica il cambio
            DispatchQueue.main.async {
                ActivityStore.shared.refreshActivities()
            }
        }
    }
    
    /// Chiude l'attività corrente, sottraendo il tempo di idle se necessario
    private func closeCurrentActivity() {
        guard var activity = currentActivity, activity.endTime == nil else { return }
        
        // Retrodatare la fine al momento dell'ultima attività utente reale
        // per non includere il periodo di idle nella durata
        let systemIdle = getSystemIdleTime()
        let effectiveEndTime: Date
        if systemIdle > pollInterval {
            // L'utente era idle: la fine reale è stata N secondi fa
            effectiveEndTime = Date().addingTimeInterval(-systemIdle)
        } else {
            effectiveEndTime = Date()
        }
        
        // Non retrodatare prima dell'inizio dell'attività
        let clampedEndTime = max(effectiveEndTime, activity.startTime)
        
        activity.endTime = clampedEndTime
        activity.durationSeconds = Int(clampedEndTime.timeIntervalSince(activity.startTime))
        activity.updatedAt = Date()

        if activity.durationSeconds < minActivityDurationToKeep, let activityId = activity.id {
            db.deleteActivity(activityId)
        } else {
            db.updateActivity(activity)
        }
        currentActivity = nil
    }
    
    /// Gestisce lo stato di idle (quando non c'è finestra attiva)
    private func handleIdle() {
        guard currentActivity != nil else { return }
        
        // Se non c'è finestra attiva, usa il tempo dall'ultima attività utente
        let idleTime = Date().timeIntervalSince(lastUserActivityTime)
        
        if idleTime > idleThreshold {
            closeCurrentActivity()
            lastWindowInfo = nil
        }
    }
    
    /// Ottiene il tempo di inattività del sistema (mouse/tastiera) in secondi via IOKit
    private func getSystemIdleTime() -> TimeInterval {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"), &iterator)
        guard result == KERN_SUCCESS else { return 0 }
        
        defer { IOObjectRelease(iterator) }
        
        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }
        
        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(entry, &unmanagedDict, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let dict = unmanagedDict?.takeRetainedValue() as? [String: Any] else { return 0 }
        
        guard let idleTime = dict["HIDIdleTime"] as? Int64 else { return 0 }
        
        // HIDIdleTime è in nanosecondi
        return TimeInterval(idleTime) / 1_000_000_000.0
    }
}

/// Pattern Matcher per classificare automaticamente le attività
class PatternMatcher {
    static let shared = PatternMatcher()
    
    struct MatchResult {
        let category: ActivityCategory
        let generalizedName: String?
    }
    
    private let db = DatabaseService.shared
    
    /// Cache delle classificazioni per evitare query DB ad ogni poll
    private var cachedClassifications: [Classification] = []
    private var cacheTimestamp: Date = .distantPast
    private let cacheTTL: TimeInterval = 30 // Ricarica ogni 30 secondi
    
    private init() {}
    
    /// Invalida la cache (da chiamare quando le classificazioni cambiano)
    func invalidateCache() {
        cacheTimestamp = .distantPast
    }
    
    /// Ottiene le classificazioni dalla cache o dal DB
    private func getClassificationsCached() -> [Classification] {
        let now = Date()
        if now.timeIntervalSince(cacheTimestamp) > cacheTTL {
            cachedClassifications = db.getClassifications()
            cacheTimestamp = now
        }
        return cachedClassifications
    }
    
    /// Cerca una corrispondenza per l'attività
    func match(appName: String, appBundleId: String, activityName: String, windowTitle: String) -> MatchResult? {
        let classifications = getClassificationsCached()
        
        // Ordina per priorità (più alta prima)
        let sortedClassifications = classifications.sorted { $0.priority > $1.priority }
        
        let activityLower = activityName.lowercased()
        let titleLower = windowTitle.lowercased()
        let bundleLower = appBundleId.lowercased()
        
        // Cerca corrispondenza nei pattern
        for classification in sortedClassifications {
            let pattern = classification.pattern.lowercased()
            
            // Pattern formato: "bundleId|keywords" oppure solo "bundleId"
            if pattern.contains("|") {
                let parts = pattern.components(separatedBy: "|")
                let patternBundleId = parts[0]
                let keywords = parts.count > 1 ? parts[1] : ""
                
                // Verifica bundle ID
                let bundleMatches = bundleLower.contains(patternBundleId) || patternBundleId.isEmpty
                
                // Verifica keywords (tutte devono essere presenti)
                var keywordsMatch = true
                if !keywords.isEmpty {
                    let keywordList = keywords.components(separatedBy: " ").filter { !$0.isEmpty }
                    keywordsMatch = keywordList.allSatisfy { keyword in
                        activityLower.contains(keyword) || titleLower.contains(keyword)
                    }
                }
                
                if bundleMatches && keywordsMatch {
                    return MatchResult(
                        category: classification.category,
                        generalizedName: classification.generalizedName
                    )
                }
            } else {
                // Pattern semplice (solo bundleId o stringa generica)
                if bundleLower.contains(pattern) || activityLower.contains(pattern) || titleLower.contains(pattern) {
                    return MatchResult(
                        category: classification.category,
                        generalizedName: classification.generalizedName
                    )
                }
            }
        }
        
        // Pattern predefiniti per app comuni
        return matchDefaultPatterns(appBundleId: appBundleId, activityName: activityName)
    }
    
    /// Pattern predefiniti per app comuni
    private func matchDefaultPatterns(appBundleId: String, activityName: String) -> MatchResult? {
        // IDE e editor = Lavoro
        let workApps = [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.jetbrains",
            "com.todesktop.230313mzl4w4u92", // Cursor
            "dev.kiro.app", // Kiro
            "com.sublimetext",
            "com.googlecode.iterm2",
            "com.apple.Terminal"
        ]
        
        for workApp in workApps {
            if appBundleId.contains(workApp) {
                return MatchResult(category: .work, generalizedName: nil)
            }
        }
        
        // Social e streaming = Svago
        let leisureApps = [
            "com.spotify",
            "com.apple.Music",
            "com.netflix",
            "tv.twitch",
            "com.tinyspeck.slackmacgap" // Slack (potrebbe essere lavoro, ma default svago)
        ]
        
        for leisureApp in leisureApps {
            if appBundleId.contains(leisureApp) {
                return MatchResult(category: .leisure, generalizedName: nil)
            }
        }
        
        // Pattern per siti web nel titolo
        let leisureSites = ["youtube", "netflix", "twitter", "facebook", "instagram", "reddit", "twitch"]
        let workSites = ["github", "gitlab", "stackoverflow", "jira", "confluence", "notion", "figma"]
        
        let activityLower = activityName.lowercased()
        
        for site in workSites {
            if activityLower.contains(site) {
                return MatchResult(category: .work, generalizedName: site)
            }
        }
        
        for site in leisureSites {
            if activityLower.contains(site) {
                return MatchResult(category: .leisure, generalizedName: site)
            }
        }
        
        return nil
    }
}




