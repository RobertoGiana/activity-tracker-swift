import XCTest
@testable import ActivityTracker

/// Test di esplorazione della bug condition.
/// Questi test codificano il comportamento ATTESO (corretto).
/// Sul codice NON fixato DEVONO FALLIRE — il fallimento conferma che il bug esiste.
final class CalendarDayDataBugExplorationTests: XCTestCase {

    // MARK: - Helpers

    /// Crea una data per oggi alle ore specificate
    private func todayAt(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
    }

    /// Crea un'attività con i parametri specificati
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
    private func makeDayData(activities: [Activity], workDay: WorkDay? = nil) -> CalendarDayData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return CalendarDayData(
            date: today,
            workSeconds: activities.filter { $0.category == .work }.reduce(0) { $0 + $1.durationSeconds },
            leisureSeconds: activities.filter { $0.category == .leisure }.reduce(0) { $0 + $1.durationSeconds },
            activities: activities,
            workDay: workDay
        )
    }

    // MARK: - Test Case 1: Wake-up notturno
    // loginwindow alle 00:00 + attività utente alle 09:00
    // Comportamento atteso: startTime == 09:00 (prima attività utente)
    // Bug: startTime == 00:00 (include loginwindow) → FAIL atteso
    // Validates: Requirements 1.1

    func testStartTimeExcludesLoginwindowDuringNightWakeup() {
        let loginwindowActivity = makeActivity(
            appName: "loginwindow",
            bundleId: "com.apple.loginwindow",
            startTime: todayAt(hour: 0, minute: 0),
            endTime: todayAt(hour: 0, minute: 1),
            durationSeconds: 60,
            category: .untracked
        )
        let xcodeActivity = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 9, minute: 0),
            endTime: todayAt(hour: 12, minute: 0),
            durationSeconds: 10800,
            category: .work
        )

        let dayData = makeDayData(activities: [loginwindowActivity, xcodeActivity])

        // Il comportamento CORRETTO: startTime deve essere 09:00 (prima attività utente)
        // Sul codice non fixato restituirà 00:00 (loginwindow) → FAIL
        let expected = todayAt(hour: 9, minute: 0)
        XCTAssertEqual(
            dayData.startTime, expected,
            "startTime dovrebbe essere 09:00 (prima attività utente), non 00:00 (loginwindow)"
        )
    }

    // MARK: - Test Case 2: ScreenSaver serale
    // Attività utente fino alle 18:00 + ScreenSaverEngine alle 23:00
    // Comportamento atteso: endTime == 18:00 (ultima attività utente)
    // Bug: endTime == 23:00 (include ScreenSaverEngine) → FAIL atteso
    // Validates: Requirements 1.2

    func testEndTimeExcludesScreenSaverEngine() {
        let safariActivity = makeActivity(
            appName: "Safari",
            bundleId: "com.apple.Safari",
            startTime: todayAt(hour: 9, minute: 0),
            endTime: todayAt(hour: 18, minute: 0),
            durationSeconds: 32400,
            category: .work
        )
        let screenSaverActivity = makeActivity(
            appName: "ScreenSaverEngine",
            bundleId: "com.apple.ScreenSaver",
            startTime: todayAt(hour: 23, minute: 0),
            endTime: todayAt(hour: 23, minute: 30),
            durationSeconds: 1800,
            category: .untracked
        )

        let dayData = makeDayData(activities: [safariActivity, screenSaverActivity])

        // Il comportamento CORRETTO: endTime deve essere 18:00 (ultima attività utente)
        // Sul codice non fixato restituirà 23:30 (ScreenSaverEngine) → FAIL
        let expected = todayAt(hour: 18, minute: 0)
        XCTAssertEqual(
            dayData.endTime, expected,
            "endTime dovrebbe essere 18:00 (ultima attività utente), non 23:30 (ScreenSaverEngine)"
        )
    }

    // MARK: - Test Case 3: isNightWork ore 0-5
    // effectiveStartTime alle 02:00 (senza customStartTime)
    // Comportamento atteso: isNightWork == true
    // Bug: isNightWork == false (controlla solo hour >= 20) → FAIL atteso
    // Validates: Requirements 1.4

    func testIsNightWorkDetectsEarlyMorningHours() {
        // Creiamo un'attività utente reale alle 02:00 (lavoro notturno effettivo)
        let nightActivity = makeActivity(
            appName: "Terminal",
            bundleId: "com.apple.Terminal",
            startTime: todayAt(hour: 2, minute: 0),
            endTime: todayAt(hour: 5, minute: 0),
            durationSeconds: 10800,
            category: .work
        )

        let dayData = makeDayData(activities: [nightActivity])

        // Il comportamento CORRETTO: isNightWork deve essere true per ore 0-5
        // Sul codice non fixato restituirà false (controlla solo hour >= 20) → FAIL
        XCTAssertTrue(
            dayData.isNightWork,
            "isNightWork dovrebbe essere true quando effectiveStartTime è alle 02:00 (ore 0-5 sono lavoro notturno)"
        )
    }

    // MARK: - Test Case 4: Solo attività di sistema
    // Solo loginwindow, nessuna attività utente
    // Comportamento atteso: startTime == nil, endTime == nil
    // Bug: startTime e endTime non-nil (include loginwindow) → FAIL atteso
    // Validates: Requirements 1.1

    func testStartTimeAndEndTimeAreNilWithOnlySystemActivities() {
        let loginwindowActivity = makeActivity(
            appName: "loginwindow",
            bundleId: "com.apple.loginwindow",
            startTime: todayAt(hour: 0, minute: 0),
            endTime: todayAt(hour: 0, minute: 5),
            durationSeconds: 300,
            category: .untracked
        )

        let dayData = makeDayData(activities: [loginwindowActivity])

        // Il comportamento CORRETTO: startTime e endTime devono essere nil
        // Sul codice non fixato restituiranno valori non-nil → FAIL
        XCTAssertNil(
            dayData.startTime,
            "startTime dovrebbe essere nil quando ci sono solo attività di sistema"
        )
        XCTAssertNil(
            dayData.endTime,
            "endTime dovrebbe essere nil quando ci sono solo attività di sistema"
        )
    }

    // MARK: - Test Case 5: Cascata standardEndTime
    // loginwindow alle 00:00 + attività utente alle 09:00
    // Comportamento atteso: standardEndTime == 18:00 (09:00 + 9h)
    // Bug: standardEndTime == 09:00 (00:00 + 9h) → FAIL atteso
    // Validates: Requirements 1.3, 1.5

    func testStandardEndTimeCascadeFromCorrectStartTime() {
        let loginwindowActivity = makeActivity(
            appName: "loginwindow",
            bundleId: "com.apple.loginwindow",
            startTime: todayAt(hour: 0, minute: 0),
            endTime: todayAt(hour: 0, minute: 1),
            durationSeconds: 60,
            category: .untracked
        )
        let xcodeActivity = makeActivity(
            appName: "Xcode",
            bundleId: "com.apple.dt.Xcode",
            startTime: todayAt(hour: 9, minute: 0),
            endTime: todayAt(hour: 18, minute: 0),
            durationSeconds: 32400,
            category: .work
        )

        let dayData = makeDayData(activities: [loginwindowActivity, xcodeActivity])

        // Il comportamento CORRETTO: standardEndTime = effectiveStartTime + 9h
        // effectiveStartTime dovrebbe essere 09:00 (prima attività utente) → standardEndTime = 18:00
        // Sul codice non fixato: effectiveStartTime = 00:00 → standardEndTime = 09:00 → FAIL
        let expected = todayAt(hour: 18, minute: 0)
        XCTAssertEqual(
            dayData.standardEndTime, expected,
            "standardEndTime dovrebbe essere 18:00 (09:00 + 9h), non 09:00 (00:00 + 9h)"
        )
    }
}
