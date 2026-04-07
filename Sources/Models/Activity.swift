import Foundation

/// Categoria dell'attività
enum ActivityCategory: String, Codable, CaseIterable {
    case work = "work"
    case leisure = "leisure"
    case untracked = "untracked"
    
    var displayName: String {
        switch self {
        case .work: return "Lavoro"
        case .leisure: return "Svago"
        case .untracked: return "Non tracciare"
        }
    }
    
    var color: String {
        switch self {
        case .work: return "blue"
        case .leisure: return "green"
        case .untracked: return "gray"
        }
    }
}

/// Rappresenta un'attività tracciata
struct Activity: Identifiable, Codable, Equatable {
    var id: Int64?
    let appName: String
    let appBundleId: String
    let windowTitle: String
    let activityName: String
    var generalizedName: String?
    var category: ActivityCategory?
    let startTime: Date
    var endTime: Date?
    var durationSeconds: Int
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: Int64? = nil,
        appName: String,
        appBundleId: String,
        windowTitle: String,
        activityName: String,
        generalizedName: String? = nil,
        category: ActivityCategory? = nil,
        startTime: Date = Date(),
        endTime: Date? = nil,
        durationSeconds: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.appName = appName
        self.appBundleId = appBundleId
        self.windowTitle = windowTitle
        self.activityName = activityName
        self.generalizedName = generalizedName
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Durata formattata come stringa
    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        let seconds = durationSeconds % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    /// Nome da visualizzare (generalizzato se disponibile, altrimenti activityName)
    var displayName: String {
        generalizedName ?? activityName
    }
}

/// Classificazione per pattern matching
struct Classification: Identifiable, Codable {
    var id: Int64?
    let pattern: String
    let category: ActivityCategory
    var generalizedName: String?
    let priority: Int
    let createdAt: Date
    
    init(
        id: Int64? = nil,
        pattern: String,
        category: ActivityCategory,
        generalizedName: String? = nil,
        priority: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pattern = pattern
        self.category = category
        self.generalizedName = generalizedName
        self.priority = priority
        self.createdAt = createdAt
    }
}

/// Pattern per generalizzazione attività
struct Pattern: Identifiable, Codable {
    var id: Int64?
    let type: PatternType
    let pattern: String
    let replacement: String
    let createdAt: Date
    
    enum PatternType: String, Codable, CaseIterable {
        case url = "url"
        case title = "title"
        case app = "app"
        
        var displayName: String {
            switch self {
            case .url: return "URL"
            case .title: return "Titolo"
            case .app: return "App"
            }
        }
    }
    
    init(
        id: Int64? = nil,
        type: PatternType,
        pattern: String,
        replacement: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.pattern = pattern
        self.replacement = replacement
        self.createdAt = createdAt
    }
}

/// Attività raggruppate
struct GroupedActivity: Identifiable {
    let id = UUID()
    let name: String
    let appName: String
    let category: ActivityCategory?
    let totalDuration: Int
    let count: Int
    let lastStartTime: Date
    let activities: [Activity]
    
    var formattedDuration: String {
        let hours = totalDuration / 3600
        let minutes = (totalDuration % 3600) / 60
        let seconds = totalDuration % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

/// Dati del calendario per un giorno
struct CalendarDayData: Identifiable {
    let id = UUID()
    let date: Date
    var workSeconds: Int
    var leisureSeconds: Int
    var activities: [Activity]
    var dayOff: DayOff? = nil
    var holidayName: String? = nil
    var workDay: WorkDay? = nil  // Personalizzazioni (ora inizio, ferie parziali)
    
    /// Tempo attivo pre-calcolato (esclude loginwindow)
    var calculatedPresenceSeconds: Int = 0
    
    /// Pre-calcolato: prima attività utente dopo le 5:00 (nil se non ce ne sono)
    var cachedFirstDaytimeStart: Date? = nil
    /// Pre-calcolato: secondi di lavoro nella fascia notturna 0:00-5:00
    var cachedNightTailWorkSeconds: Int = 0
    
    // MARK: - System Activity Exclusion
    
    /// Nomi app di sistema da escludere dai calcoli temporali
    static let excludedAppNames: Set<String> = ["loginwindow", "ScreenSaverEngine", "LockScreen"]
    /// Bundle ID di sistema da escludere dai calcoli temporali
    static let excludedBundleIds: Set<String> = ["com.apple.loginwindow", "com.apple.ScreenSaver", "com.apple.LockScreen"]
    
    /// Verifica se un'attività è di sistema (da escludere dai calcoli)
    static func isSystemActivity(_ activity: Activity) -> Bool {
        return excludedAppNames.contains(activity.appName)
            || excludedBundleIds.contains(where: { activity.appBundleId.contains($0) })
            || activity.appName.lowercased() == "loginwindow"
    }
    
    // MARK: - Computed Properties Base
    
    var totalSeconds: Int {
        workSeconds + leisureSeconds
    }
    
    var workPercentage: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(workSeconds) / Double(totalSeconds)
    }
    
    var dominantCategory: ActivityCategory {
        if workPercentage > 0.7 {
            return .work
        } else if workPercentage < 0.3 {
            return .leisure
        } else {
            return .work // Misto, mostra come lavoro
        }
    }
    
    // MARK: - Day Type
    
    /// È un giorno del weekend
    var isWeekend: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
    
    /// È un giorno festivo italiano
    var isHoliday: Bool {
        holidayName != nil
    }
    
    /// È un giorno di ferie (giorno intero)
    var isDayOff: Bool {
        dayOff != nil
    }
    
    /// Ore di ferie parziali
    var vacationHours: Int {
        workDay?.vacationHours ?? 0
    }
    
    /// È un giorno lavorativo (non weekend, non festivo, non ferie giorno intero)
    var isWorkingDay: Bool {
        !isWeekend && !isHoliday && !isDayOff
    }
    
    /// Descrizione del tipo di giorno speciale
    var specialDayDescription: String? {
        if let holiday = holidayName {
            return "🎉 \(holiday)"
        }
        if let off = dayOff {
            return off.type.displayName
        }
        if isWeekend {
            return "Weekend"
        }
        return nil
    }
    
    // MARK: - Timesheet (Nuova Logica)
    
    /// True se ci sono attività utente sia prima delle 5:00 che dopo le 5:00
    var hasNightTailAndDaytimeWork: Bool {
        guard let start = startTime else { return false }
        let hour = Calendar.current.component(.hour, from: start)
        return hour < 5 && cachedFirstDaytimeStart != nil
    }
    
    /// Ora di inizio lavoro effettiva (personalizzata o prima attività)
    var effectiveStartTime: Date? {
        if let customStart = workDay?.startTimeAsDate() {
            return customStart
        }
        if hasNightTailAndDaytimeWork, let daytime = cachedFirstDaytimeStart {
            return daytime
        }
        return startTime
    }
    
    /// Ora fine lavoro standard (inizio + 9h = 8h lavoro + 1h pranzo)
    var standardEndTime: Date? {
        guard let start = effectiveStartTime else { return nil }
        return Calendar.current.date(byAdding: .hour, value: 9, to: start)
    }
    
    /// Verifica se è lavoro PURAMENTE notturno (tutte le attività sono in fascia notturna)
    var isNightWork: Bool {
        guard let start = effectiveStartTime else { return false }
        let hour = Calendar.current.component(.hour, from: start)
        return hour >= 20 || hour < 5
    }
    
    /// Ore standard giornaliere (8h - ferie parziali, 0 se non lavorativo)
    var standardWorkSeconds: Int {
        if isWeekend || isHoliday || isDayOff {
            return 0
        }
        let standardHours = max(0, 8 - vacationHours)
        return standardHours * 3600
    }
    
    /// Ore di lavoro regolari (entro l'orario standard)
    var regularWorkSeconds: Int {
        if !isWorkingDay {
            return 0
        }
        // Se c'è coda notturna + lavoro diurno, le ore regolari sono quelle diurne entro lo standard
        if hasNightTailAndDaytimeWork {
            return min(workSeconds, standardWorkSeconds)
        }
        if isNightWork {
            return 0
        }
        return min(workSeconds, standardWorkSeconds)
    }
    
    /// Ore di straordinario (attività "Lavoro" FUORI dalla fascia inizio-fine standard)
    var overtimeSeconds: Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        // Solo attività "Lavoro" che INIZIANO in questo giorno, ESCLUDENDO call in background
        let workActivities = activities.filter { activity in
            activity.category == .work &&
            activity.startTime >= dayStart &&
            activity.startTime < dayEnd &&
            !activity.activityName.lowercased().contains("call -")
        }
        
        // Calcola ore di lavoro effettive (cappate al tempo attivo per evitare doppio conteggio)
        let rawWorkSeconds = workActivities.reduce(0) { $0 + $1.durationSeconds }
        let dayWorkSeconds = min(rawWorkSeconds, calculatedPresenceSeconds)
        
        // Weekend, festivi, ferie giorno intero → tutto il lavoro è straordinario
        if !isWorkingDay {
            return dayWorkSeconds
        }
        
        // Coda notturna + lavoro diurno: la parte notturna (0-5) è straordinario,
        // il lavoro diurno segue le regole normali (straordinario solo dopo standardEndTime)
        if hasNightTailAndDaytimeWork {
            var overtime = cachedNightTailWorkSeconds
            
            guard let endStandard = standardEndTime else {
                return overtime
            }
            
            // Aggiungi straordinario diurno (dopo standardEndTime)
            for activity in workActivities {
                // Salta attività notturne (già contate sopra)
                if activity.startTime < (cachedFirstDaytimeStart ?? dayEnd) { continue }
                guard let actEnd = activity.endTime else { continue }
                
                if actEnd > endStandard {
                    if activity.startTime >= endStandard {
                        overtime += activity.durationSeconds
                    } else {
                        let overtimePart = Int(actEnd.timeIntervalSince(endStandard))
                        overtime += max(0, overtimePart)
                    }
                }
            }
            
            return overtime
        }
        
        // Lavoro puramente notturno (solo attività >= 20:00 o solo 0-5) → tutto straordinario
        if isNightWork {
            return dayWorkSeconds
        }
        
        // Orario standard
        guard let endStandard = standardEndTime else {
            return 0
        }
        
        // Straordinario = lavoro DOPO la fine standard
        var overtime = 0
        for activity in workActivities {
            guard let actEnd = activity.endTime else { continue }
            
            if actEnd > endStandard {
                let actStart = activity.startTime
                if actStart >= endStandard {
                    overtime += activity.durationSeconds
                } else {
                    let overtimePart = Int(actEnd.timeIntervalSince(endStandard))
                    overtime += max(0, overtimePart)
                }
            }
        }
        
        return overtime
    }
    
    /// Differenza rispetto alle ore standard (considera che le 8h sono sempre "fatte")
    var workDifferenceSeconds: Int {
        // Se non è un giorno lavorativo, non c'è differenza
        if !isWorkingDay {
            return 0
        }
        // Le ore standard sono sempre considerate fatte, quindi la differenza è solo gli straordinari
        return overtimeSeconds
    }
    
    /// Ore di presenza (somma durate attività che INTERSECANO il giorno, ESCLUDE attività di sistema)
    /// Le attività che attraversano mezzanotte vengono splittate
    var presenceSeconds: Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        var total = 0
        
        for activity in activities {
            // Escludi attività di sistema (schermo bloccato, screensaver, etc.)
            if CalendarDayData.isSystemActivity(activity) {
                continue
            }
            
            let actEndOpt = activity.endTime ?? (calendar.isDateInToday(date) ? Date() : nil)
            guard let rawEnd = actEndOpt else { continue }
            
            // L'attività interseca il giorno?
            guard activity.startTime < dayEnd && rawEnd > dayStart else { continue }
            
            // Prendi solo la porzione nel giorno
            let actStart = max(activity.startTime, dayStart)
            let actEnd = min(rawEnd, dayEnd)
            
            if actEnd > actStart {
                total += Int(actEnd.timeIntervalSince(actStart))
            }
        }
        
        return total
    }
    
    /// Range presenza (da prima a ultima attività che INTERSECA il giorno, ESCLUDE attività di sistema e call in background)
    var presenceRange: (start: Date, end: Date)? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        // Attività che intersecano questo giorno, escludendo attività di sistema e call
        let dayActivities = activities.filter { activity in
            if CalendarDayData.isSystemActivity(activity) { return false }
            if activity.activityName.lowercased().contains("call -") { return false }
            let actEnd = activity.endTime ?? (calendar.isDateInToday(date) ? Date() : activity.startTime)
            return activity.startTime < dayEnd && actEnd > dayStart
        }
        
        guard !dayActivities.isEmpty else { return nil }
        
        // Trova l'inizio più presto (clampato a inizio giorno)
        var earliestStart = dayEnd
        for activity in dayActivities {
            let actStart = max(activity.startTime, dayStart)
            if actStart < earliestStart {
                earliestStart = actStart
            }
        }
        
        // Trova la fine più tardi (clampata a fine giorno)
        var latestEnd = dayStart
        for activity in dayActivities {
            var actEnd: Date
            if let end = activity.endTime {
                actEnd = min(end, dayEnd)
            } else if calendar.isDateInToday(date) {
                actEnd = Date()
            } else {
                actEnd = activity.startTime
            }
            if actEnd > latestEnd {
                latestEnd = actEnd
            }
        }
        
        guard latestEnd > earliestStart else { return nil }
        
        return (earliestStart, latestEnd)
    }
    
    /// Ora di inizio lavoro (prima attività utente del giorno, esclude attività di sistema e call)
    var startTime: Date? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        return activities
            .filter { $0.startTime >= dayStart && $0.startTime < dayEnd
                      && !CalendarDayData.isSystemActivity($0)
                      && !$0.activityName.lowercased().contains("call -") }
            .min(by: { $0.startTime < $1.startTime })?.startTime
    }
    
    /// Ora di fine lavoro (ultima attività utente del giorno, esclude attività di sistema e call)
    var endTime: Date? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        let dayActivities = activities.filter { $0.startTime >= dayStart && $0.startTime < dayEnd
                                                && !CalendarDayData.isSystemActivity($0)
                                                && !$0.activityName.lowercased().contains("call -") }
        
        guard let lastActivity = dayActivities.max(by: { ($0.endTime ?? $0.startTime) < ($1.endTime ?? $1.startTime) }) else {
            return nil
        }
        
        if let end = lastActivity.endTime {
            // Tronca a mezzanotte se necessario
            return min(end, dayEnd)
        } else if calendar.isDateInToday(date) {
            // Solo per oggi: usa l'ora corrente come fine provvisoria
            return Date()
        } else {
            // Giorno passato senza endTime: usa startTime + durationSeconds come stima
            return lastActivity.startTime.addingTimeInterval(Double(lastActivity.durationSeconds))
        }
    }
    
    // MARK: - Formatted Strings
    
    var formattedWorkHours: String {
        formatHoursMinutes(workSeconds)
    }
    
    var formattedRegularHours: String {
        formatHoursMinutes(regularWorkSeconds)
    }
    
    /// Straordinario arrotondato alla mezzora superiore (30 min)
    var roundedOvertimeSeconds: Int {
        guard overtimeSeconds > 0 else { return 0 }
        return ((overtimeSeconds + 1799) / 1800) * 1800
    }
    
    var formattedOvertimeHours: String {
        formatHoursMinutes(roundedOvertimeSeconds)
    }
    
    var formattedPresenceHours: String {
        formatHoursMinutes(presenceSeconds)
    }
    
    var formattedStartTime: String? {
        guard let start = startTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: start)
    }
    
    var formattedEndTime: String? {
        guard let end = endTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: end)
    }
    
    private func formatHoursMinutes(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}




