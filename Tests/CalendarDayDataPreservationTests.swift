import XCTest
@testable import ActivityTracker

/// Test di preservation: verificano il comportamento che NON deve cambiare dopo il fix.
/// Questi test DEVONO PASSARE sia sul codice non fixato che dopo il fix.
/// Seguono la metodologia observation-first: osserviamo il comportamento attuale
/// per input non-buggy (senza attività di sistema) e lo codifichiamo come baseline.
final class CalendarDayDataPreservationTests: XCTestCase {

    // MARK: - Helpers (stessi pattern di CalendarDayDataBugExplorationTests)

    /// Crea una data per oggi alle ore specificate
    private func todayAt(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
    }

    /// Crea un'attività utente con i parametri specificati
    private func makeActivity(
        appName: String,
        bundleId: String = "com.test.app",
        startTime: Date,
        endTime: Date? = nil,
        durationSeconds: Int = 3600,
        category: ActivityCategory? = .work
    ) -> Activity {
        Activity(
            id: nil,
            appName: appName,
            appBundleId: bundleId,
            windowTitle: "",
            activityName: appName,
            category: category,
            startTime: startTime,
            endTime: endTime,
            durationSeconds: durationSeconds
        )
    }

    /// Crea un CalendarDayData per oggi con le attività specificate
    private func makeDayData(
        activities: [Activity],
        workDay: WorkDay? = nil,
        dayOff: DayOff? = nil,
        holidayName: String? = nil
    ) -> CalendarDayData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return CalendarDayData(
            date: today,
            workSeconds: activities.filter { $0.category == .work }.reduce(0) { $0 + $1.durationSeconds },
            leisureSeconds: activities.filter { $0.category == .leisure }.reduce(0) { $0 + $1.durationSeconds },
            activities: activities,
            dayOff: dayOff,
            holidayName: holidayName,
            workDay: workDay
        )
    }

    /// Crea un CalendarDayData per una data specifica
    private func makeDayDataForDate(
        _ date: Date,
        activities: [Activity],
        workDay: WorkDay? = nil,
        dayOff: DayOff? = nil,
        holidayName: String? = nil
    ) -> CalendarDayData {
        CalendarDayData(
            date: date,
            workSeconds: activities.filter { $0.category == .work }.reduce(0) { $0 + $1.durationSeconds },
            leisureSeconds: activities.filter { $0.category == .leisure }.reduce(0) { $0 + $1.durationSeconds },
            activities: activities,
            dayOff: dayOff,
            holidayName: holidayName,
            workDay: workDay
        )
    }

    /// Crea un'attività ad una data specifica
    private func makeActivityAt(
        _ date: Date,
        hour: Int,
        minute: Int = 0,
        appName: String,
        bundleId: String = "com.test.app",
        endHour: Int? = nil,
        endMinute: Int = 0,
        durationSeconds: Int = 3600,
        category: ActivityCategory? = .work
    ) -> Activity {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        var end: Date? = nil
        if let eh = endHour {
            end = calendar.date(bySettingHour: eh, minute: endMinute, second: 0, of: date)!
        }
        return Activity(
            id: nil,
            appName: appName,
            appBundleId: bundleId,
            windowTitle: "",
            activityName: appName,
            category: category,
            startTime: start,
            endTime: end,
            durationSeconds: durationSeconds
        )
    }

    // MARK: - Property 2a: startTime e endTime con solo attività utente
    // Per qualsiasi CalendarDayData con solo attività utente,
    // startTime == prima attività del giorno e endTime corrisponde all'ultima attività.
    // Validates: Requirements 3.2

    /// Caso base: due attività utente, startTime = prima, endTime = ultima
    func testStartTimeIsFirstUserActivity() {
        let xcode = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 9, minute: 0),
            endTime: todayAt(hour: 12, minute: 0),
            durationSeconds: 10800,
            category: .work
        )
        let safari = makeActivity(
            appName: "Safari",
            bundleId: "com.apple.Safari",
            startTime: todayAt(hour: 13, minute: 0),
            endTime: todayAt(hour: 18, minute: 0),
            durationSeconds: 18000,
            category: .work
        )

        let dayData = makeDayData(activities: [xcode, safari])

        // Osservazione: startTime = 09:00 (prima attività)
        XCTAssertEqual(
            dayData.startTime, todayAt(hour: 9, minute: 0),
            "startTime deve essere 09:00 (prima attività utente)"
        )
    }

    func testEndTimeIsLastUserActivity() {
        let xcode = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 9, minute: 0),
            endTime: todayAt(hour: 12, minute: 0),
            durationSeconds: 10800,
            category: .work
        )
        let safari = makeActivity(
            appName: "Safari",
            bundleId: "com.apple.Safari",
            startTime: todayAt(hour: 13, minute: 0),
            endTime: todayAt(hour: 18, minute: 0),
            durationSeconds: 18000,
            category: .work
        )

        let dayData = makeDayData(activities: [xcode, safari])

        // Osservazione: endTime = 18:00 (fine ultima attività)
        XCTAssertEqual(
            dayData.endTime, todayAt(hour: 18, minute: 0),
            "endTime deve essere 18:00 (fine ultima attività utente)"
        )
    }

    /// Singola attività utente: startTime e endTime coerenti
    func testSingleUserActivityStartAndEndTime() {
        let vscode = makeActivity(
            appName: "Visual Studio Code",
            bundleId: "com.microsoft.VSCode",
            startTime: todayAt(hour: 10, minute: 30),
            endTime: todayAt(hour: 17, minute: 45),
            durationSeconds: 26100,
            category: .work
        )

        let dayData = makeDayData(activities: [vscode])

        XCTAssertEqual(dayData.startTime, todayAt(hour: 10, minute: 30))
        XCTAssertEqual(dayData.endTime, todayAt(hour: 17, minute: 45))
    }

    /// Tre attività utente non ordinate: startTime = prima cronologicamente
    func testStartTimeWithMultipleUnorderedActivities() {
        let slack = makeActivity(
            appName: "Slack",
            bundleId: "com.tinyspeck.slackmacgap",
            startTime: todayAt(hour: 11, minute: 0),
            endTime: todayAt(hour: 12, minute: 0),
            durationSeconds: 3600,
            category: .work
        )
        let xcode = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 8, minute: 30),
            endTime: todayAt(hour: 10, minute: 30),
            durationSeconds: 7200,
            category: .work
        )
        let safari = makeActivity(
            appName: "Safari",
            bundleId: "com.apple.Safari",
            startTime: todayAt(hour: 14, minute: 0),
            endTime: todayAt(hour: 18, minute: 30),
            durationSeconds: 16200,
            category: .work
        )

        let dayData = makeDayData(activities: [slack, xcode, safari])

        // startTime = 08:30 (Xcode, la prima cronologicamente)
        XCTAssertEqual(dayData.startTime, todayAt(hour: 8, minute: 30))
        // endTime = 18:30 (Safari, l'ultima cronologicamente)
        XCTAssertEqual(dayData.endTime, todayAt(hour: 18, minute: 30))
    }

    /// Mix di categorie (work + leisure): startTime/endTime considerano tutte le attività
    func testStartEndTimeIncludesAllCategories() {
        let leisure = makeActivity(
            appName: "YouTube",
            bundleId: "com.google.Chrome",
            startTime: todayAt(hour: 8, minute: 0),
            endTime: todayAt(hour: 9, minute: 0),
            durationSeconds: 3600,
            category: .leisure
        )
        let work = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 9, minute: 30),
            endTime: todayAt(hour: 17, minute: 0),
            durationSeconds: 27000,
            category: .work
        )

        let dayData = makeDayData(activities: [leisure, work])

        // startTime include anche leisure (08:00)
        XCTAssertEqual(dayData.startTime, todayAt(hour: 8, minute: 0))
        XCTAssertEqual(dayData.endTime, todayAt(hour: 17, minute: 0))
    }

    // MARK: - Property 2b: customStartTime ha priorità
    // Per qualsiasi CalendarDayData con customStartTime impostato,
    // effectiveStartTime == orario personalizzato (indipendentemente dalle attività).
    // Validates: Requirements 3.1

    /// customStartTime sovrascrive effectiveStartTime
    func testEffectiveStartTimeUsesCustomStartTime() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let xcode = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 10, minute: 0),
            endTime: todayAt(hour: 18, minute: 0),
            durationSeconds: 28800,
            category: .work
        )

        let workDay = WorkDay(
            date: today,
            customStartTime: "08:30",
            vacationHours: 0
        )

        let dayData = makeDayData(activities: [xcode], workDay: workDay)

        // Osservazione: effectiveStartTime = 08:30 (customStartTime), non 10:00 (prima attività)
        let expected = todayAt(hour: 8, minute: 30)
        XCTAssertEqual(
            dayData.effectiveStartTime, expected,
            "effectiveStartTime deve usare customStartTime (08:30), non la prima attività (10:00)"
        )
    }

    /// customStartTime con valore diverso dall'attività
    func testCustomStartTimeOverridesEvenWhenLater() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let xcode = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 7, minute: 0),
            endTime: todayAt(hour: 16, minute: 0),
            durationSeconds: 32400,
            category: .work
        )

        // customStartTime DOPO la prima attività
        let workDay = WorkDay(
            date: today,
            customStartTime: "09:00",
            vacationHours: 0
        )

        let dayData = makeDayData(activities: [xcode], workDay: workDay)

        // effectiveStartTime = 09:00 (custom), non 07:00 (prima attività)
        XCTAssertEqual(dayData.effectiveStartTime, todayAt(hour: 9, minute: 0))
    }

    /// Senza customStartTime, effectiveStartTime == startTime
    func testEffectiveStartTimeFallsBackToStartTime() {
        let xcode = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 9, minute: 15),
            endTime: todayAt(hour: 18, minute: 0),
            durationSeconds: 31500,
            category: .work
        )

        let dayData = makeDayData(activities: [xcode])

        // Senza customStartTime, effectiveStartTime == startTime
        XCTAssertEqual(dayData.effectiveStartTime, todayAt(hour: 9, minute: 15))
        XCTAssertEqual(dayData.effectiveStartTime, dayData.startTime)
    }

    /// customStartTime produce standardEndTime corretto (custom + 9h)
    func testStandardEndTimeWithCustomStartTime() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let xcode = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 10, minute: 0),
            endTime: todayAt(hour: 19, minute: 0),
            durationSeconds: 32400,
            category: .work
        )

        let workDay = WorkDay(
            date: today,
            customStartTime: "08:00",
            vacationHours: 0
        )

        let dayData = makeDayData(activities: [xcode], workDay: workDay)

        // standardEndTime = 08:00 + 9h = 17:00
        XCTAssertEqual(dayData.standardEndTime, todayAt(hour: 17, minute: 0))
    }

    // MARK: - Property 2c: Giorni non lavorativi → tutto è straordinario
    // Per qualsiasi CalendarDayData di giorno non lavorativo (weekend/festivo/ferie),
    // tutto il lavoro è conteggiato come straordinario.
    // Validates: Requirements 3.3

    /// Weekend: tutto il lavoro è straordinario
    func testWeekendAllWorkIsOvertime() {
        let calendar = Calendar.current
        // Trova il prossimo sabato
        let today = Date()
        var saturday = today
        while calendar.component(.weekday, from: saturday) != 7 {
            saturday = calendar.date(byAdding: .day, value: 1, to: saturday)!
        }
        saturday = calendar.startOfDay(for: saturday)

        let xcode = makeActivityAt(
            saturday,
            hour: 10, minute: 0,
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            endHour: 14, endMinute: 0,
            durationSeconds: 14400,
            category: .work
        )

        let dayData = makeDayDataForDate(saturday, activities: [xcode])

        // Osservazione: weekend → isWorkingDay = false, standardWorkSeconds = 0, tutto è overtime
        XCTAssertTrue(dayData.isWeekend, "Sabato deve essere weekend")
        XCTAssertFalse(dayData.isWorkingDay, "Weekend non è giorno lavorativo")
        XCTAssertEqual(dayData.standardWorkSeconds, 0, "Ore standard = 0 nel weekend")
        XCTAssertEqual(
            dayData.overtimeSeconds, 14400,
            "Nel weekend tutto il lavoro (14400s) deve essere straordinario"
        )
    }

    /// Domenica: tutto il lavoro è straordinario
    func testSundayAllWorkIsOvertime() {
        let calendar = Calendar.current
        let today = Date()
        var sunday = today
        while calendar.component(.weekday, from: sunday) != 1 {
            sunday = calendar.date(byAdding: .day, value: 1, to: sunday)!
        }
        sunday = calendar.startOfDay(for: sunday)

        let terminal = makeActivityAt(
            sunday,
            hour: 9, minute: 0,
            appName: "Terminal",
            bundleId: "com.apple.Terminal",
            endHour: 13, endMinute: 0,
            durationSeconds: 14400,
            category: .work
        )

        let dayData = makeDayDataForDate(sunday, activities: [terminal])

        XCTAssertTrue(dayData.isWeekend)
        XCTAssertEqual(dayData.overtimeSeconds, 14400)
    }

    /// Festivo: tutto il lavoro è straordinario
    func testHolidayAllWorkIsOvertime() {
        let calendar = Calendar.current
        // Usa un lunedì (giorno feriale) ma con holidayName impostato
        let today = Date()
        var monday = today
        while calendar.component(.weekday, from: monday) != 2 {
            monday = calendar.date(byAdding: .day, value: 1, to: monday)!
        }
        monday = calendar.startOfDay(for: monday)

        let xcode = makeActivityAt(
            monday,
            hour: 9, minute: 0,
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            endHour: 17, endMinute: 0,
            durationSeconds: 28800,
            category: .work
        )

        let dayData = makeDayDataForDate(
            monday,
            activities: [xcode],
            holidayName: "Festa della Repubblica"
        )

        XCTAssertTrue(dayData.isHoliday)
        XCTAssertFalse(dayData.isWorkingDay)
        XCTAssertEqual(dayData.standardWorkSeconds, 0)
        XCTAssertEqual(dayData.overtimeSeconds, 28800)
    }

    /// Ferie giorno intero: tutto il lavoro è straordinario
    func testDayOffAllWorkIsOvertime() {
        let calendar = Calendar.current
        let today = Date()
        var tuesday = today
        while calendar.component(.weekday, from: tuesday) != 3 {
            tuesday = calendar.date(byAdding: .day, value: 1, to: tuesday)!
        }
        tuesday = calendar.startOfDay(for: tuesday)

        let xcode = makeActivityAt(
            tuesday,
            hour: 10, minute: 0,
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            endHour: 12, endMinute: 0,
            durationSeconds: 7200,
            category: .work
        )

        let dayOff = DayOff(date: tuesday, type: .vacation, note: "Ferie")
        let dayData = makeDayDataForDate(tuesday, activities: [xcode], dayOff: dayOff)

        XCTAssertTrue(dayData.isDayOff)
        XCTAssertFalse(dayData.isWorkingDay)
        XCTAssertEqual(dayData.overtimeSeconds, 7200)
    }

    // MARK: - Property 2d: presenceSeconds e presenceRange coerenti (già filtrano sistema)
    // presenceSeconds e presenceRange producono gli stessi risultati
    // (entrambi già escludono attività di sistema nel codice attuale).
    // Validates: Requirements 3.5, 3.6

    /// presenceSeconds con solo attività utente = somma durate
    func testPresenceSecondsWithOnlyUserActivities() {
        let xcode = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 9, minute: 0),
            endTime: todayAt(hour: 12, minute: 0),
            durationSeconds: 10800,
            category: .work
        )
        let safari = makeActivity(
            appName: "Safari",
            bundleId: "com.apple.Safari",
            startTime: todayAt(hour: 13, minute: 0),
            endTime: todayAt(hour: 18, minute: 0),
            durationSeconds: 18000,
            category: .work
        )

        let dayData = makeDayData(activities: [xcode, safari])

        // presenceSeconds = somma delle durate calcolate da start/end (non durationSeconds)
        // Xcode: 09:00-12:00 = 10800s, Safari: 13:00-18:00 = 18000s → totale = 28800s
        XCTAssertEqual(
            dayData.presenceSeconds, 28800,
            "presenceSeconds deve essere 28800 (3h + 5h = 8h)"
        )
    }

    /// presenceRange con solo attività utente = da prima a ultima
    func testPresenceRangeWithOnlyUserActivities() {
        let xcode = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 9, minute: 0),
            endTime: todayAt(hour: 12, minute: 0),
            durationSeconds: 10800,
            category: .work
        )
        let safari = makeActivity(
            appName: "Safari",
            bundleId: "com.apple.Safari",
            startTime: todayAt(hour: 13, minute: 0),
            endTime: todayAt(hour: 18, minute: 0),
            durationSeconds: 18000,
            category: .work
        )

        let dayData = makeDayData(activities: [xcode, safari])

        // presenceRange: start = 09:00, end = 18:00
        let range = dayData.presenceRange
        XCTAssertNotNil(range)
        XCTAssertEqual(range?.start, todayAt(hour: 9, minute: 0))
        XCTAssertEqual(range?.end, todayAt(hour: 18, minute: 0))
    }

    /// presenceSeconds e presenceRange sono coerenti tra loro
    func testPresenceSecondsAndRangeConsistency() {
        let terminal = makeActivity(
            appName: "Terminal",
            bundleId: "com.apple.Terminal",
            startTime: todayAt(hour: 10, minute: 0),
            endTime: todayAt(hour: 16, minute: 0),
            durationSeconds: 21600,
            category: .work
        )

        let dayData = makeDayData(activities: [terminal])

        // Con una singola attività, presenceSeconds == durata range
        let range = dayData.presenceRange
        XCTAssertNotNil(range)
        if let r = range {
            let rangeSeconds = Int(r.end.timeIntervalSince(r.start))
            // presenceSeconds = tempo effettivo delle attività nel range
            XCTAssertEqual(dayData.presenceSeconds, rangeSeconds,
                "Con una singola attività, presenceSeconds deve corrispondere alla durata del range")
        }
    }

    // MARK: - Preservation aggiuntiva: vacationHours riduce ore standard
    // Validates: Requirements 3.8

    /// vacationHours riduce standardWorkSeconds
    func testVacationHoursReduceStandardWorkSeconds() {
        let calendar = Calendar.current
        let today = Date()
        // Trova un giorno feriale (lunedì-venerdì)
        var weekday = today
        while calendar.component(.weekday, from: weekday) == 1 || calendar.component(.weekday, from: weekday) == 7 {
            weekday = calendar.date(byAdding: .day, value: 1, to: weekday)!
        }
        weekday = calendar.startOfDay(for: weekday)

        let xcode = makeActivityAt(
            weekday,
            hour: 9, minute: 0,
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            endHour: 18, endMinute: 0,
            durationSeconds: 32400,
            category: .work
        )

        let workDay = WorkDay(
            date: weekday,
            customStartTime: nil,
            vacationHours: 4  // 4 ore di ferie parziali
        )

        let dayData = makeDayDataForDate(weekday, activities: [xcode], workDay: workDay)

        // standardWorkSeconds = (8 - 4) * 3600 = 14400
        XCTAssertEqual(dayData.vacationHours, 4)
        XCTAssertEqual(
            dayData.standardWorkSeconds, 14400,
            "Con 4 ore di ferie, standardWorkSeconds deve essere (8-4)*3600 = 14400"
        )
    }

    /// vacationHours = 0 → standardWorkSeconds = 8h
    func testNoVacationHoursFullStandardWork() {
        let calendar = Calendar.current
        let today = Date()
        var weekday = today
        while calendar.component(.weekday, from: weekday) == 1 || calendar.component(.weekday, from: weekday) == 7 {
            weekday = calendar.date(byAdding: .day, value: 1, to: weekday)!
        }
        weekday = calendar.startOfDay(for: weekday)

        let xcode = makeActivityAt(
            weekday,
            hour: 9, minute: 0,
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            endHour: 18, endMinute: 0,
            durationSeconds: 32400,
            category: .work
        )

        let dayData = makeDayDataForDate(weekday, activities: [xcode])

        // Senza ferie: standardWorkSeconds = 8 * 3600 = 28800
        XCTAssertEqual(dayData.standardWorkSeconds, 28800)
    }

    // MARK: - Preservation: nessuna attività → valori nil/zero
    // Validates: Requirements 3.4

    /// Nessuna attività: startTime e endTime sono nil
    func testNoActivitiesReturnsNilTimes() {
        let dayData = makeDayData(activities: [])

        XCTAssertNil(dayData.startTime)
        XCTAssertNil(dayData.endTime)
        XCTAssertNil(dayData.effectiveStartTime)
        XCTAssertNil(dayData.standardEndTime)
        XCTAssertEqual(dayData.overtimeSeconds, 0)
    }
}
