import Foundation
import Combine

/// Store centrale per la gestione dello stato dell'app
class ActivityStore: ObservableObject {
    static let shared = ActivityStore()
    
    @Published var activities: [Activity] = [] {
        didSet { rebuildGroupedActivities() }
    }
    @Published var calendarData: [CalendarDayData] = []
    @Published private(set) var cachedGroupedActivities: [GroupedActivity] = []
    @Published var patterns: [Pattern] = []
    @Published var classifications: [Classification] = []
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var selectedActivity: Activity?
    @Published var isLoading: Bool = false
    
    // Controllo refresh - pausa durante interazione utente
    @Published var isUserInteracting: Bool = false
    private var interactionTimer: Timer?
    
    private let db = DatabaseService.shared
    private let dbQueue = DispatchQueue(label: "com.robertogiana.ActivityTracker.db", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    private var calendarRefreshCounter: Int = 0
    private var calendarCacheKey: String?
    private var calendarCacheLastBuilt: Date = .distantPast
    private let calendarCacheTTL: TimeInterval = 60
    
    private init() {
        // Carica dati iniziali
        refreshAll()
        
        // Refresh attività ogni 15s; calendario ogni 5 minuti (20 cicli)
        Timer.publish(every: 15.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, !self.isUserInteracting else { return }
                self.refreshActivities()
                self.calendarRefreshCounter += 1
                if self.calendarRefreshCounter >= 20 {
                    self.calendarRefreshCounter = 0
                    self.refreshCalendarData()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Segnala che l'utente sta interagendo (blocca refresh)
    func userStartedInteracting() {
        isUserInteracting = true
        interactionTimer?.invalidate()
        
        // Riattiva refresh dopo 5 secondi di inattività
        interactionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.isUserInteracting = false
        }
    }
    
    /// Aggiorna tutti i dati
    func refreshAll() {
        refreshActivities()
        refreshCalendarData()
        refreshPatterns()
        refreshClassifications()
    }
    
    /// Aggiorna la lista delle attività
    func refreshActivities() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        activities = db.getActivities(startDate: startOfDay, endDate: endOfDay)
    }
    
    /// Aggiorna i dati del calendario in background (cache in-memory con TTL 60s + invalidazione esplicita)
    func refreshCalendarData(force: Bool = false) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentMonth)
        let month = calendar.component(.month, from: currentMonth)
        let key = "\(year)-\(month)"
        let now = Date()
        let isFresh = calendarCacheKey == key
            && now.timeIntervalSince(calendarCacheLastBuilt) < calendarCacheTTL
            && !calendarData.isEmpty
        if !force && isFresh {
            return
        }

        let targetMonth = currentMonth
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            let data = self.db.getCalendarData(year: year, month: month)
            DispatchQueue.main.async {
                // Drop result se nel frattempo l'utente ha cambiato mese
                guard self.currentMonth == targetMonth else { return }
                self.calendarData = data
                self.calendarCacheKey = key
                self.calendarCacheLastBuilt = Date()
            }
        }
    }

    private func invalidateCalendarCache() {
        calendarCacheKey = nil
        calendarCacheLastBuilt = .distantPast
    }
    
    /// Aggiorna i pattern
    func refreshPatterns() {
        patterns = db.getPatterns()
    }
    
    /// Aggiorna le classificazioni
    func refreshClassifications() {
        classifications = db.getClassifications()
    }
    
    /// Classifica un'attività specifica
    func classifyActivity(_ activity: Activity, category: ActivityCategory, generalizedName: String?) {
        // 1. Aggiorna l'attività originale
        var updatedActivity = activity
        updatedActivity.category = category
        updatedActivity.generalizedName = generalizedName
        updatedActivity.updatedAt = Date()
        
        if activity.id != nil {
            db.updateActivity(updatedActivity)
        }
        
        // 2. Se c'è un generalizedName, aggiorna TUTTE le attività nel DB che contengono quelle parole chiave
        if let pattern = generalizedName, !pattern.isEmpty {
            let keywords = pattern.lowercased().components(separatedBy: " ").filter { !$0.isEmpty }
            
            // Cerca TUTTE le attività nel database che matchano (non solo quelle del giorno)
            let matchingActivities = db.getActivitiesMatchingKeywords(keywords, bundleId: activity.appBundleId)
            
            print("🔍 Trovate \(matchingActivities.count) attività che matchano '\(pattern)'")
            
            for var act in matchingActivities {
                if act.id != activity.id {
                    act.category = category
                    act.generalizedName = generalizedName
                    act.updatedAt = Date()
                    db.updateActivity(act)
                }
            }
        }
        
        // 3. Crea classificazione per pattern matching futuro
        let classificationPattern: String
        if let genName = generalizedName, !genName.isEmpty {
            // Usa il pattern basato sulle parole chiave
            classificationPattern = "\(activity.appBundleId)|\(genName.lowercased())"
        } else {
            // Pattern specifico per questa attività
            classificationPattern = "\(activity.appBundleId)|\(activity.activityName.lowercased())"
        }
        
        let classification = Classification(
            pattern: classificationPattern,
            category: category,
            generalizedName: generalizedName,
            priority: 10
        )
        _ = db.insertClassification(classification)
        
        // Invalida la cache del PatternMatcher
        PatternMatcher.shared.invalidateCache()
        invalidateCalendarCache()

        refreshAll()
    }

    /// Classifica un'intera app (tutte le attività)
    func classifyApp(bundleId: String, appName: String, category: ActivityCategory, generalizedName: String?) {
        // Aggiorna tutte le attività esistenti di questa app
        let appActivities = activities.filter { $0.appBundleId == bundleId }
        for var activity in appActivities {
            activity.category = category
            activity.generalizedName = generalizedName ?? appName
            activity.updatedAt = Date()
            db.updateActivity(activity)
        }
        
        // Crea classificazione per pattern matching futuro (intera app)
        let classification = Classification(
            pattern: bundleId,
            category: category,
            generalizedName: generalizedName ?? appName,
            priority: 5 // Priorità media per pattern app
        )
        _ = db.insertClassification(classification)
        
        // Invalida la cache del PatternMatcher
        PatternMatcher.shared.invalidateCache()
        invalidateCalendarCache()

        refreshAll()
    }

    /// Aggiunge un nuovo pattern
    func addPattern(_ pattern: Pattern) {
        _ = db.insertPattern(pattern)
        refreshPatterns()
    }
    
    /// Elimina un pattern
    func deletePattern(_ patternId: Int64) {
        db.deletePattern(patternId)
        refreshPatterns()
    }
    
    /// Cambia il mese visualizzato
    func changeMonth(by months: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: months, to: currentMonth) {
            currentMonth = newMonth
            invalidateCalendarCache()
            refreshCalendarData()
        }
    }
    
    /// Seleziona una data
    func selectDate(_ date: Date) {
        selectedDate = date
        refreshActivities()
    }
    
    /// Attività raggruppate per nome (memoizzato — ricalcolato solo quando `activities` cambia)
    var groupedActivities: [GroupedActivity] {
        cachedGroupedActivities
    }

    private func rebuildGroupedActivities() {
        let grouped = Dictionary(grouping: activities) { $0.displayName }
        cachedGroupedActivities = grouped.map { name, acts in
            let totalDuration = acts.reduce(0) { $0 + $1.durationSeconds }
            let category = acts.first?.category
            let appName = acts.first?.appName ?? ""
            let lastActivity = acts.max(by: { $0.startTime < $1.startTime })
            return GroupedActivity(
                name: name,
                appName: appName,
                category: category,
                totalDuration: totalDuration,
                count: acts.count,
                lastStartTime: lastActivity?.startTime ?? Date(),
                activities: acts
            )
        }.sorted { $0.lastStartTime > $1.lastStartTime }
    }
    
    /// Elimina una classificazione
    func deleteClassification(_ classificationId: Int64) {
        db.deleteClassification(classificationId)
        PatternMatcher.shared.invalidateCache()
        refreshClassifications()
    }
    
    // MARK: - Days Off (Ferie, Permessi, etc.)
    
    /// Aggiunge un giorno di assenza (optimistic + DB in background)
    func addDayOff(date: Date, type: DayOffType, note: String? = nil) {
        let dayOff = DayOff(date: date, type: type, note: note)
        if let idx = calendarData.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            calendarData[idx].dayOff = dayOff
        }
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            _ = self.db.insertDayOff(dayOff)
            DispatchQueue.main.async {
                self.invalidateCalendarCache()
                self.refreshCalendarData(force: true)
            }
        }
    }

    /// Rimuove un giorno di assenza (optimistic + DB in background)
    func removeDayOff(date: Date) {
        if let idx = calendarData.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            calendarData[idx].dayOff = nil
        }
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            self.db.deleteDayOff(date)
            DispatchQueue.main.async {
                self.invalidateCalendarCache()
                self.refreshCalendarData(force: true)
            }
        }
    }
    
    /// Ottiene il giorno di assenza per una data
    func getDayOff(for date: Date) -> DayOff? {
        db.getDayOff(for: date)
    }
    
    /// Tutti i giorni di assenza
    var allDaysOff: [DayOff] {
        db.getAllDaysOff()
    }
    
    // MARK: - Work Days (Personalizzazioni giornata)
    
    /// Salva/aggiorna le personalizzazioni di un giorno lavorativo
    /// Optimistic update sul giorno modificato per feedback UI istantaneo, poi DB write + refresh in background
    func saveWorkDay(date: Date, customStartTime: String?, vacationHours: Int) {
        let workDay = WorkDay(
            date: date,
            customStartTime: customStartTime,
            vacationHours: vacationHours
        )

        // Aggiornamento ottimistico in-memory: la UI mostra subito la nuova ora
        if let idx = calendarData.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            calendarData[idx].workDay = workDay
        }

        dbQueue.async { [weak self] in
            guard let self = self else { return }
            self.db.upsertWorkDay(workDay)
            DispatchQueue.main.async {
                self.invalidateCalendarCache()
                self.refreshCalendarData(force: true)
            }
        }
    }
    
    /// Ottiene le personalizzazioni per una data
    func getWorkDay(for date: Date) -> WorkDay? {
        db.getWorkDay(for: date)
    }
    
    /// Calcola statistiche giornaliere
    var todayStats: (work: Int, leisure: Int, total: Int) {
        // Tempo attivo (escluso attività di sistema e call parallele)
        let activeSeconds = activities
            .filter { activity in
                if CalendarDayData.isSystemActivity(activity) { return false }
                if activity.activityName.lowercased().contains("call -") { return false }
                return true
            }
            .reduce(0) { $0 + $1.durationSeconds }
        
        // Lavoro totale (incluse call)
        let rawWorkSeconds = activities
            .filter { $0.category == .work }
            .reduce(0) { $0 + $1.durationSeconds }
        
        // Lavoro = MIN(lavoro, tempo attivo) per evitare doppio conteggio
        let workSeconds = min(rawWorkSeconds, activeSeconds)
        
        let leisureSeconds = activities
            .filter { $0.category == .leisure }
            .reduce(0) { $0 + $1.durationSeconds }
        
        return (workSeconds, leisureSeconds, workSeconds + leisureSeconds)
    }
    
    /// Calcola statistiche mensili
    var monthStats: (work: Int, leisure: Int, total: Int) {
        let workSeconds = calendarData.reduce(0) { $0 + $1.workSeconds }
        let leisureSeconds = calendarData.reduce(0) { $0 + $1.leisureSeconds }
        return (workSeconds, leisureSeconds, workSeconds + leisureSeconds)
    }
    
    /// Formatta i secondi in stringa leggibile
    func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
    
    /// Formatta i secondi in stringa breve (senza secondi per stats)
    func formatDurationShort(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}




