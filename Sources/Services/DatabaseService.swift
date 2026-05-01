import Foundation
import SQLite

/// Servizio per la gestione del database SQLite
class DatabaseService {
    static let shared = DatabaseService()
    
    private var db: Connection?
    
    // Tabelle
    private let activities = Table("activities")
    private let classifications = Table("classifications")
    private let patterns = Table("patterns")
    private let daysOff = Table("days_off")
    private let workDays = Table("work_days")
    
    // Colonne Activities
    private let id = Expression<Int64>("id")
    private let appName = Expression<String>("app_name")
    private let appBundleId = Expression<String>("app_bundle_id")
    private let windowTitle = Expression<String>("window_title")
    private let activityName = Expression<String>("activity_name")
    private let generalizedName = Expression<String?>("generalized_name")
    private let category = Expression<String?>("category")
    private let startTime = Expression<Double>("start_time")
    private let endTime = Expression<Double?>("end_time")
    private let durationSeconds = Expression<Int>("duration_seconds")
    private let createdAt = Expression<Double>("created_at")
    private let updatedAt = Expression<Double>("updated_at")
    
    // Colonne Classifications
    private let pattern = Expression<String>("pattern")
    private let priority = Expression<Int>("priority")
    
    // Colonne Patterns
    private let patternType = Expression<String>("type")
    private let patternValue = Expression<String>("pattern")
    private let replacement = Expression<String>("replacement")
    
    // Colonne Days Off
    private let dayOffDate = Expression<Double>("date")
    private let dayOffType = Expression<String>("type")
    private let dayOffNote = Expression<String?>("note")
    
    // Colonne Work Days
    private let workDayDate = Expression<Double>("date")
    private let customStartTime = Expression<String?>("custom_start_time")
    private let vacationHours = Expression<Int>("vacation_hours")
    private let workDayNotes = Expression<String?>("notes")
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let path = getDBPath()
            print("📁 Database path: \(path)")

            db = try Connection(path)
            try db?.execute("PRAGMA journal_mode=WAL;")
            try db?.execute("PRAGMA synchronous=NORMAL;")
            try db?.execute("PRAGMA temp_store=MEMORY;")
            try db?.execute("PRAGMA mmap_size=268435456;")
            try db?.execute("PRAGMA cache_size=-16384;") // 16MB di page cache
            createTables()
            try? db?.execute("PRAGMA optimize;")
            print("✅ Database inizializzato (WAL)")
        } catch {
            print("❌ Errore inizializzazione database: \(error)")
        }
    }
    
    private func getDBPath() -> String {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ActivityTracker", isDirectory: true)
        
        // Crea directory se non esiste
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        
        return appDir.appendingPathComponent("activity-tracker.db").path
    }
    
    private func createTables() {
        guard let db = db else { return }
        
        do {
            // Tabella activities
            try db.run(activities.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(appName)
                t.column(appBundleId)
                t.column(windowTitle)
                t.column(activityName)
                t.column(generalizedName)
                t.column(category)
                t.column(startTime)
                t.column(endTime)
                t.column(durationSeconds, defaultValue: 0)
                t.column(createdAt)
                t.column(updatedAt)
            })
            
            // Tabella classifications
            try db.run(classifications.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(pattern, unique: true)
                t.column(category)
                t.column(generalizedName)
                t.column(priority, defaultValue: 0)
                t.column(createdAt)
            })
            
            // Tabella patterns
            try db.run(patterns.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(patternType)
                t.column(patternValue)
                t.column(replacement)
                t.column(createdAt)
            })
            
            // Tabella days_off (ferie, permessi, malattia)
            try db.run(daysOff.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(dayOffDate, unique: true)
                t.column(dayOffType)
                t.column(dayOffNote)
                t.column(createdAt)
            })
            
            // Tabella work_days (personalizzazioni giornate lavorative)
            try db.run(workDays.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(workDayDate, unique: true)
                t.column(customStartTime)
                t.column(vacationHours, defaultValue: 0)
                t.column(workDayNotes)
                t.column(createdAt)
            })
            
            // Indici per performance
            try db.run(activities.createIndex(startTime, ifNotExists: true))
            try db.run(activities.createIndex(category, ifNotExists: true))
            try db.run(activities.createIndex(appName, ifNotExists: true))
            try db.run(activities.createIndex(appBundleId, startTime, ifNotExists: true))
            
            print("✅ Tabelle create")
        } catch {
            print("❌ Errore creazione tabelle: \(error)")
        }
    }
    
    // MARK: - Activity CRUD
    
    func insertActivity(_ activity: Activity) -> Int64? {
        guard let db = db else { return nil }
        
        do {
            let insert = activities.insert(
                appName <- activity.appName,
                appBundleId <- activity.appBundleId,
                windowTitle <- activity.windowTitle,
                activityName <- activity.activityName,
                generalizedName <- activity.generalizedName,
                category <- activity.category?.rawValue,
                startTime <- activity.startTime.timeIntervalSince1970,
                endTime <- activity.endTime?.timeIntervalSince1970,
                durationSeconds <- activity.durationSeconds,
                createdAt <- activity.createdAt.timeIntervalSince1970,
                updatedAt <- activity.updatedAt.timeIntervalSince1970
            )
            
            let rowId = try db.run(insert)
            return rowId
        } catch {
            print("❌ Errore inserimento attività: \(error)")
            return nil
        }
    }
    
    func deleteActivity(_ activityId: Int64) {
        guard let db = db else { return }
        do {
            let row = activities.filter(id == activityId)
            try db.run(row.delete())
        } catch {
            print("❌ Errore eliminazione attività: \(error)")
        }
    }

    func updateActivity(_ activity: Activity) {
        guard let db = db, let activityId = activity.id else { return }
        
        do {
            let row = activities.filter(id == activityId)
            try db.run(row.update(
                generalizedName <- activity.generalizedName,
                category <- activity.category?.rawValue,
                endTime <- activity.endTime?.timeIntervalSince1970,
                durationSeconds <- activity.durationSeconds,
                updatedAt <- Date().timeIntervalSince1970
            ))
        } catch {
            print("❌ Errore aggiornamento attività: \(error)")
        }
    }
    
    func getActivities(startDate: Date? = nil, endDate: Date? = nil, category filterCategory: ActivityCategory? = nil, limit: Int? = nil) -> [Activity] {
        guard let db = db else { return [] }
        
        var query = activities.order(startTime.desc)
        
        if let start = startDate {
            query = query.filter(startTime >= start.timeIntervalSince1970)
        }
        
        if let end = endDate {
            query = query.filter(startTime <= end.timeIntervalSince1970)
        }
        
        if let cat = filterCategory {
            query = query.filter(category == cat.rawValue)
        }
        
        if let lim = limit {
            query = query.limit(lim)
        }
        
        do {
            return try db.prepare(query).map { row in
                Activity(
                    id: row[id],
                    appName: row[appName],
                    appBundleId: row[appBundleId],
                    windowTitle: row[windowTitle],
                    activityName: row[activityName],
                    generalizedName: row[generalizedName],
                    category: row[category].flatMap { ActivityCategory(rawValue: $0) },
                    startTime: Date(timeIntervalSince1970: row[startTime]),
                    endTime: row[endTime].map { Date(timeIntervalSince1970: $0) },
                    durationSeconds: row[durationSeconds],
                    createdAt: Date(timeIntervalSince1970: row[createdAt]),
                    updatedAt: Date(timeIntervalSince1970: row[updatedAt])
                )
            }
        } catch {
            print("❌ Errore lettura attività: \(error)")
            return []
        }
    }
    
    func getActivityById(_ activityId: Int64) -> Activity? {
        guard let db = db else { return nil }
        
        do {
            let query = activities.filter(id == activityId)
            if let row = try db.pluck(query) {
                return Activity(
                    id: row[id],
                    appName: row[appName],
                    appBundleId: row[appBundleId],
                    windowTitle: row[windowTitle],
                    activityName: row[activityName],
                    generalizedName: row[generalizedName],
                    category: row[category].flatMap { ActivityCategory(rawValue: $0) },
                    startTime: Date(timeIntervalSince1970: row[startTime]),
                    endTime: row[endTime].map { Date(timeIntervalSince1970: $0) },
                    durationSeconds: row[durationSeconds],
                    createdAt: Date(timeIntervalSince1970: row[createdAt]),
                    updatedAt: Date(timeIntervalSince1970: row[updatedAt])
                )
            }
        } catch {
            print("❌ Errore lettura attività: \(error)")
        }
        return nil
    }
    
    /// Cerca attività che contengono le keywords nel titolo, tutto via SQL
    func getActivitiesMatchingKeywords(_ keywords: [String], bundleId: String? = nil) -> [Activity] {
        guard let db = db, !keywords.isEmpty else { return [] }

        do {
            var query = activities.order(startTime.desc)
            if let bundle = bundleId {
                query = query.filter(appBundleId.like("%\(bundle)%"))
            }
            // Tutte le keyword devono matchare activity_name o window_title (SQLite LIKE è case-insensitive su ASCII)
            for keyword in keywords {
                let pattern = "%\(keyword)%"
                query = query.filter(activityName.like(pattern) || windowTitle.like(pattern))
            }

            return try db.prepare(query).map { row in
                Activity(
                    id: row[id],
                    appName: row[appName],
                    appBundleId: row[appBundleId],
                    windowTitle: row[windowTitle],
                    activityName: row[activityName],
                    generalizedName: row[generalizedName],
                    category: row[category].flatMap { ActivityCategory(rawValue: $0) },
                    startTime: Date(timeIntervalSince1970: row[startTime]),
                    endTime: row[endTime].map { Date(timeIntervalSince1970: $0) },
                    durationSeconds: row[durationSeconds],
                    createdAt: Date(timeIntervalSince1970: row[createdAt]),
                    updatedAt: Date(timeIntervalSince1970: row[updatedAt])
                )
            }
        } catch {
            print("❌ Errore ricerca attività: \(error)")
            return []
        }
    }
    
    // MARK: - Classification CRUD
    
    func insertClassification(_ classification: Classification) -> Int64? {
        guard let db = db else { return nil }
        
        do {
            let insert = classifications.insert(
                pattern <- classification.pattern,
                category <- classification.category.rawValue,
                generalizedName <- classification.generalizedName,
                priority <- classification.priority,
                createdAt <- classification.createdAt.timeIntervalSince1970
            )
            
            return try db.run(insert)
        } catch {
            print("❌ Errore inserimento classificazione: \(error)")
            return nil
        }
    }
    
    func getClassifications() -> [Classification] {
        guard let db = db else { return [] }
        
        do {
            return try db.prepare(classifications.order(priority.desc, createdAt.desc)).map { row in
                Classification(
                    id: row[id],
                    pattern: row[pattern],
                    category: ActivityCategory(rawValue: row[category]!) ?? .untracked,
                    generalizedName: row[generalizedName],
                    priority: row[priority],
                    createdAt: Date(timeIntervalSince1970: row[createdAt])
                )
            }
        } catch {
            print("❌ Errore lettura classificazioni: \(error)")
            return []
        }
    }
    
    // MARK: - Pattern CRUD
    
    func insertPattern(_ pat: Pattern) -> Int64? {
        guard let db = db else { return nil }
        
        do {
            let insert = patterns.insert(
                patternType <- pat.type.rawValue,
                patternValue <- pat.pattern,
                replacement <- pat.replacement,
                createdAt <- pat.createdAt.timeIntervalSince1970
            )
            
            return try db.run(insert)
        } catch {
            print("❌ Errore inserimento pattern: \(error)")
            return nil
        }
    }
    
    func getPatterns() -> [Pattern] {
        guard let db = db else { return [] }
        
        do {
            return try db.prepare(patterns.order(createdAt.desc)).map { row in
                Pattern(
                    id: row[id],
                    type: Pattern.PatternType(rawValue: row[patternType])!,
                    pattern: row[patternValue],
                    replacement: row[replacement],
                    createdAt: Date(timeIntervalSince1970: row[createdAt])
                )
            }
        } catch {
            print("❌ Errore lettura pattern: \(error)")
            return []
        }
    }
    
    func deletePattern(_ patternId: Int64) {
        guard let db = db else { return }
        
        do {
            let row = patterns.filter(id == patternId)
            try db.run(row.delete())
        } catch {
            print("❌ Errore eliminazione pattern: \(error)")
        }
    }
    
    func deleteClassification(_ classificationId: Int64) {
        guard let db = db else { return }
        
        do {
            let row = classifications.filter(id == classificationId)
            try db.run(row.delete())
        } catch {
            print("❌ Errore eliminazione classificazione: \(error)")
        }
    }
    
    // MARK: - Days Off CRUD
    
    func insertDayOff(_ dayOff: DayOff) -> Int64? {
        guard let db = db else { return nil }
        
        // Normalizza la data a mezzanotte
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: dayOff.date)
        
        do {
            let insert = daysOff.insert(
                dayOffDate <- normalizedDate.timeIntervalSince1970,
                dayOffType <- dayOff.type.rawValue,
                dayOffNote <- dayOff.note,
                createdAt <- Date().timeIntervalSince1970
            )
            
            return try db.run(insert)
        } catch {
            // Se esiste già, aggiorna
            updateDayOff(DayOff(id: nil, date: normalizedDate, type: dayOff.type, note: dayOff.note))
            return nil
        }
    }
    
    func updateDayOff(_ dayOff: DayOff) {
        guard let db = db else { return }
        
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: dayOff.date)
        
        do {
            let row = daysOff.filter(dayOffDate == normalizedDate.timeIntervalSince1970)
            try db.run(row.update(
                dayOffType <- dayOff.type.rawValue,
                dayOffNote <- dayOff.note
            ))
        } catch {
            print("❌ Errore aggiornamento giorno assenza: \(error)")
        }
    }
    
    func deleteDayOff(_ date: Date) {
        guard let db = db else { return }
        
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        do {
            let row = daysOff.filter(dayOffDate == normalizedDate.timeIntervalSince1970)
            try db.run(row.delete())
        } catch {
            print("❌ Errore eliminazione giorno assenza: \(error)")
        }
    }
    
    func getDayOff(for date: Date) -> DayOff? {
        guard let db = db else { return nil }
        
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        do {
            let query = daysOff.filter(dayOffDate == normalizedDate.timeIntervalSince1970)
            if let row = try db.pluck(query) {
                return DayOff(
                    id: row[id],
                    date: Date(timeIntervalSince1970: row[dayOffDate]),
                    type: DayOffType(rawValue: row[dayOffType]) ?? .vacation,
                    note: row[dayOffNote]
                )
            }
        } catch {
            print("❌ Errore lettura giorno assenza: \(error)")
        }
        return nil
    }
    
    func getDaysOff(year: Int, month: Int) -> [DayOff] {
        guard let db = db else { return [] }
        
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = month
        startComponents.day = 1
        
        guard let startOfMonth = calendar.date(from: startComponents),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }
        
        do {
            let query = daysOff
                .filter(dayOffDate >= startOfMonth.timeIntervalSince1970)
                .filter(dayOffDate < endOfMonth.timeIntervalSince1970)
                .order(dayOffDate.asc)
            
            return try db.prepare(query).map { row in
                DayOff(
                    id: row[id],
                    date: Date(timeIntervalSince1970: row[dayOffDate]),
                    type: DayOffType(rawValue: row[dayOffType]) ?? .vacation,
                    note: row[dayOffNote]
                )
            }
        } catch {
            print("❌ Errore lettura giorni assenza: \(error)")
            return []
        }
    }
    
    func getAllDaysOff() -> [DayOff] {
        guard let db = db else { return [] }
        
        do {
            return try db.prepare(daysOff.order(dayOffDate.desc)).map { row in
                DayOff(
                    id: row[id],
                    date: Date(timeIntervalSince1970: row[dayOffDate]),
                    type: DayOffType(rawValue: row[dayOffType]) ?? .vacation,
                    note: row[dayOffNote]
                )
            }
        } catch {
            print("❌ Errore lettura giorni assenza: \(error)")
            return []
        }
    }
    
    // MARK: - Work Days CRUD
    
    func upsertWorkDay(_ workDay: WorkDay) {
        guard let db = db else { return }
        
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: workDay.date)
        
        do {
            // Prima prova a fare update
            let row = workDays.filter(workDayDate == normalizedDate.timeIntervalSince1970)
            let updateCount = try db.run(row.update(
                customStartTime <- workDay.customStartTime,
                vacationHours <- workDay.vacationHours,
                workDayNotes <- workDay.notes
            ))
            
            // Se non ha aggiornato nulla, inserisci
            if updateCount == 0 {
                let insert = workDays.insert(
                    workDayDate <- normalizedDate.timeIntervalSince1970,
                    customStartTime <- workDay.customStartTime,
                    vacationHours <- workDay.vacationHours,
                    workDayNotes <- workDay.notes,
                    createdAt <- Date().timeIntervalSince1970
                )
                _ = try db.run(insert)
            }
        } catch {
            print("❌ Errore salvataggio work day: \(error)")
        }
    }
    
    func getWorkDay(for date: Date) -> WorkDay? {
        guard let db = db else { return nil }
        
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)
        
        do {
            let query = workDays.filter(workDayDate == normalizedDate.timeIntervalSince1970)
            if let row = try db.pluck(query) {
                return WorkDay(
                    id: row[id],
                    date: Date(timeIntervalSince1970: row[workDayDate]),
                    customStartTime: row[customStartTime],
                    vacationHours: row[vacationHours],
                    notes: row[workDayNotes]
                )
            }
        } catch {
            print("❌ Errore lettura work day: \(error)")
        }
        return nil
    }
    
    func getWorkDays(year: Int, month: Int) -> [WorkDay] {
        guard let db = db else { return [] }
        
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = month
        startComponents.day = 1
        
        guard let startOfMonth = calendar.date(from: startComponents),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }
        
        do {
            let query = workDays
                .filter(workDayDate >= startOfMonth.timeIntervalSince1970)
                .filter(workDayDate < endOfMonth.timeIntervalSince1970)
                .order(workDayDate.asc)
            
            return try db.prepare(query).map { row in
                WorkDay(
                    id: row[id],
                    date: Date(timeIntervalSince1970: row[workDayDate]),
                    customStartTime: row[customStartTime],
                    vacationHours: row[vacationHours],
                    notes: row[workDayNotes]
                )
            }
        } catch {
            print("❌ Errore lettura work days: \(error)")
            return []
        }
    }
    
    // MARK: - Calendar Data
    
    func getCalendarData(year: Int, month: Int) -> [CalendarDayData] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!

        // Carica tutte le ferie e workDays del mese
        let monthDaysOff = getDaysOff(year: year, month: month)
        let monthWorkDays = getWorkDays(year: year, month: month)

        // Index per accesso O(1) per giorno (timestamp di startOfDay)
        var daysOffByTs: [TimeInterval: DayOff] = [:]
        for d in monthDaysOff { daysOffByTs[calendar.startOfDay(for: d.date).timeIntervalSince1970] = d }
        var workDaysByTs: [TimeInterval: WorkDay] = [:]
        for w in monthWorkDays { workDaysByTs[calendar.startOfDay(for: w.date).timeIntervalSince1970] = w }

        // SINGOLA query per tutte le attività del mese
        let allMonthActivities = getActivities(startDate: startOfMonth, endDate: endOfMonth)

        // Partiziona le attività per giorno
        var activitiesByDay: [Int: [Activity]] = [:]
        activitiesByDay.reserveCapacity(range.count)
        for activity in allMonthActivities {
            let day = calendar.component(.day, from: activity.startTime)
            activitiesByDay[day, default: []].append(activity)
        }

        var result: [CalendarDayData] = []
        result.reserveCapacity(range.count)

        for day in range {
            components.day = day
            guard let date = calendar.date(from: components) else { continue }

            let dayActivities = activitiesByDay[day] ?? []
            
            // Calcola tempo attivo escludendo attività di sistema
            let activeSeconds = dayActivities
                .filter { activity in
                    if CalendarDayData.isSystemActivity(activity) { return false }
                    // Escludi call in background (tracciate in parallelo)
                    if activity.activityName.lowercased().contains("call -") { return false }
                    return true
                }
                .reduce(0) { $0 + $1.durationSeconds }
            
            // Somma tutto il lavoro (incluse call)
            let rawWorkSeconds = dayActivities
                .filter { $0.category == .work }
                .reduce(0) { $0 + $1.durationSeconds }
            
            // Lavoro = MIN(lavoro tracciato, tempo attivo) per evitare doppio conteggio
            let workSeconds = min(rawWorkSeconds, activeSeconds)
            
            let leisureSeconds = dayActivities
                .filter { $0.category == .leisure }
                .reduce(0) { $0 + $1.durationSeconds }
            
            // Lookup O(1) per ferie e workDay tramite timestamp di startOfDay
            let dayKey = calendar.startOfDay(for: date).timeIntervalSince1970
            let dayOff = daysOffByTs[dayKey]
            let workDay = workDaysByTs[dayKey]
            
            // Verifica se è un festivo
            let holiday = HolidayService.isHoliday(date)
            
            var dayData = CalendarDayData(
                date: date,
                workSeconds: workSeconds,
                leisureSeconds: leisureSeconds,
                activities: dayActivities,
                dayOff: dayOff,
                holidayName: holiday.name,
                workDay: workDay,
                calculatedPresenceSeconds: activeSeconds,
                cachedFirstDaytimeStart: Self.computeFirstDaytimeStart(date: date, activities: dayActivities),
                cachedNightTailWorkSeconds: Self.computeNightTailWorkSeconds(date: date, activities: dayActivities)
            )
            // Pre-calcola le proprietà più chiamate dalla View per evitare iterazioni a ogni rebuild
            dayData.cachedPresenceSeconds = dayData.presenceSeconds
            dayData.cachedDayStartTime = dayData.startTime
            dayData.cachedDayEndTime = dayData.endTime
            dayData.cachedPresenceRange = dayData.presenceRange
            dayData.cachedOvertimeSeconds = dayData.overtimeSeconds
            result.append(dayData)
        }

        return result
    }
    
    // MARK: - Night Tail Helpers
    
    /// Pre-calcola la prima attività utente dopo le 5:00
    private static func computeFirstDaytimeStart(date: Date, activities: [Activity]) -> Date? {
        let calendar = Calendar.current
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        var comp = calendar.dateComponents([.year, .month, .day], from: date)
        comp.hour = 5
        comp.minute = 0
        guard let threshold = calendar.date(from: comp) else { return nil }
        
        return activities
            .filter { $0.startTime >= threshold && $0.startTime < dayEnd
                      && !CalendarDayData.isSystemActivity($0) }
            .min(by: { $0.startTime < $1.startTime })?.startTime
    }
    
    /// Pre-calcola i secondi di lavoro nella fascia 0:00-5:00
    private static func computeNightTailWorkSeconds(date: Date, activities: [Activity]) -> Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        var comp = calendar.dateComponents([.year, .month, .day], from: date)
        comp.hour = 5
        comp.minute = 0
        guard let threshold = calendar.date(from: comp) else { return 0 }
        
        var total = 0
        for activity in activities {
            guard activity.category == .work,
                  activity.startTime >= dayStart,
                  activity.startTime < threshold,
                  !CalendarDayData.isSystemActivity(activity) else { continue }
            
            let actEnd = activity.endTime ?? activity.startTime.addingTimeInterval(Double(activity.durationSeconds))
            let clampedEnd = min(actEnd, threshold)
            let secs = Int(clampedEnd.timeIntervalSince(activity.startTime))
            total += max(0, secs)
        }
        return total
    }
    
    // MARK: - Reset
    
    func resetDatabase() {
        guard let db = db else { return }
        
        do {
            try db.run(activities.delete())
            try db.run(classifications.delete())
            try db.run(patterns.delete())
            print("✅ Database resettato")
        } catch {
            print("❌ Errore reset database: \(error)")
        }
    }
    
    /// Elimina attività più vecchie di N giorni per contenere la crescita del DB
    func purgeOldActivities(olderThanDays days: Int) -> Int {
        guard let db = db else { return 0 }
        
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) else { return 0 }
        
        do {
            let oldActivities = activities.filter(startTime < cutoffDate.timeIntervalSince1970)
            let count = try db.run(oldActivities.delete())
            print("🗑️ Eliminate \(count) attività più vecchie di \(days) giorni")
            return count
        } catch {
            print("❌ Errore pulizia attività vecchie: \(error)")
            return 0
        }
    }
    
    /// Conta il numero totale di attività nel database
    func totalActivityCount() -> Int {
        guard let db = db else { return 0 }
        do {
            return try db.scalar(activities.count)
        } catch {
            return 0
        }
    }
}




