import SwiftUI
import AppKit

@main
struct ActivityTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var activityStore = ActivityStore.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(activityStore)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        Settings {
            SettingsView()
                .environmentObject(activityStore)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        // Richiedi permessi Accessibility
        PermissionsService.shared.requestAccessibilityPermissions()

        // Purge attività più vecchie di 90 giorni in background
        DispatchQueue.global(qos: .utility).async {
            _ = DatabaseService.shared.purgeOldActivities(olderThanDays: 90)
        }

        // Avvia il monitoraggio attività
        ActivityMonitor.shared.startMonitoring()

        // Avvia il monitoraggio call (Teams, Zoom, etc.)
        CallDetector.shared.startMonitoring()

        print("✅ Activity Tracker avviato!")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ActivityMonitor.shared.stopMonitoring()
        CallDetector.shared.stopMonitoring()
        print("Activity Tracker chiuso")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Non chiudere l'app quando si chiude la finestra (rimane nella menu bar)
        return false
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Activity Tracker")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Menu contestuale
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Apri Activity Tracker", action: #selector(openMainWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Esci", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func togglePopover() {
        openMainWindow()
    }
    
    @objc func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}




