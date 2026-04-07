import Foundation
import AVFoundation
import CoreAudio
import AppKit
import IOKit

/// Servizio per rilevare call attive (Teams, Zoom, etc.)
class CallDetector: ObservableObject {
    static let shared = CallDetector()
    
    @Published var isInCall: Bool = false
    @Published var callApp: String? = nil
    
    private var timer: Timer?
    private var callStartTime: Date?
    private var currentCallActivity: Activity?
    
    private let db = DatabaseService.shared
    
    // App di videoconferenza NATIVE (basta che siano in esecuzione + mic attivo)
    private let nativeCallApps: [(bundleId: String, name: String)] = [
        ("com.microsoft.teams", "Microsoft Teams"),
        ("com.microsoft.teams2", "Microsoft Teams"),
        ("us.zoom.xos", "Zoom"),
        ("com.slack.Slack", "Slack"),
        ("com.webex.meetingmanager", "Webex"),
        ("com.cisco.webexmeetingsapp", "Webex"),
        ("com.hnc.Discord", "Discord")
    ]
    
    // Browser: richiedono verifica titolo finestra per distinguere call reali da web app generiche
    private let browserBundleIds: Set<String> = [
        "com.google.chrome",
        "com.apple.safari"
    ]
    
    // Keyword nel titolo finestra che indicano una call reale nel browser
    private let browserCallKeywords: [String] = [
        "google meet", "meet.google.com",
        "zoom", "zoom.us",
        "microsoft teams",
        "webex",
        "whereby", "whereby.com",
        "jitsi",
        "around.co",
        "gather.town",
        "tuple"
    ]
    
    private init() {}
    
    /// Avvia il monitoraggio delle call
    func startMonitoring() {
        print("📞 Avvio monitoraggio call...")
        
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkForActiveCall()
        }
        
        // Prima verifica immediata
        checkForActiveCall()
    }
    
    /// Ferma il monitoraggio
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        
        if isInCall {
            endCall()
        }
    }
    
    /// Controlla se c'è una call attiva
    private func checkForActiveCall() {
        // Non registrare call se il sistema è idle (PC in sleep/screensaver)
        let systemIdle = getSystemIdleTime()
        if systemIdle > 120 { // 2 minuti di idle = probabilmente in sleep
            if isInCall {
                endCall()
            }
            return
        }
        
        let micInUse = isMicrophoneInUse()
        let callAppInfo = findActiveCallApp()
        
        if micInUse, let appInfo = callAppInfo {
            if !isInCall {
                // Nuova call iniziata
                startCall(appName: appInfo.name, bundleId: appInfo.bundleId)
            } else {
                // Call in corso, aggiorna durata
                updateCallDuration()
            }
        } else if isInCall {
            // Call terminata
            endCall()
        }
    }
    
    /// Verifica se il microfono è in uso
    private func isMicrophoneInUse() -> Bool {
        // Metodo 1: Controlla tramite CoreAudio
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceId: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceId
        )
        
        guard status == noErr else { return false }
        
        // Controlla se il dispositivo sta registrando
        var isRunning: UInt32 = 0
        propertySize = UInt32(MemoryLayout<UInt32>.size)
        propertyAddress.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        
        let runningStatus = AudioObjectGetPropertyData(
            deviceId,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &isRunning
        )
        
        return runningStatus == noErr && isRunning != 0
    }
    
    /// Trova l'app di call attiva
    /// - App native: basta che siano in esecuzione
    /// - Browser: richiede che il titolo della finestra attiva contenga keyword di call
    private func findActiveCallApp() -> (name: String, bundleId: String)? {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // 1. Cerca app native di call (priorità alta)
        for (knownBundleId, appName) in nativeCallApps {
            for app in runningApps {
                if let bundleId = app.bundleIdentifier?.lowercased(),
                   bundleId.contains(knownBundleId.lowercased()) {
                    return (appName, bundleId)
                }
            }
        }
        
        // 2. Per i browser, verifica il titolo della finestra attiva
        if let windowInfo = WindowTracker.shared.getActiveWindow() {
            let bundleLower = windowInfo.appBundleId.lowercased()
            let titleLower = windowInfo.windowTitle.lowercased()
            let activityLower = windowInfo.activityName.lowercased()
            
            for browserBundleId in browserBundleIds {
                if bundleLower.contains(browserBundleId) {
                    // Il browser è in primo piano — verifica se il titolo indica una call
                    for keyword in browserCallKeywords {
                        if titleLower.contains(keyword) || activityLower.contains(keyword) {
                            return ("Google Meet", bundleLower)
                        }
                    }
                    // Browser attivo ma non è una call → ignora
                    return nil
                }
            }
        }
        
        return nil
    }
    
    /// Inizia a tracciare una call
    private func startCall(appName: String, bundleId: String) {
        print("📞 Call iniziata su \(appName)")
        
        isInCall = true
        callApp = appName
        callStartTime = Date()
        
        // Crea attività per la call
        let activity = Activity(
            appName: appName,
            appBundleId: bundleId,
            windowTitle: "In call",
            activityName: "Call - \(appName)",
            generalizedName: "Videochiamata",
            category: .work, // Le call sono considerate lavoro
            startTime: Date()
        )
        
        if let id = db.insertActivity(activity) {
            currentCallActivity = db.getActivityById(id)
        }
    }
    
    /// Aggiorna la durata della call
    private func updateCallDuration() {
        guard var activity = currentCallActivity,
              let startTime = callStartTime else { return }
        
        let now = Date()
        activity.durationSeconds = Int(now.timeIntervalSince(startTime))
        activity.updatedAt = now
        
        db.updateActivity(activity)
        
        // Ricarica
        if let id = activity.id {
            currentCallActivity = db.getActivityById(id)
        }
    }
    
    /// Termina la call
    private func endCall() {
        guard var activity = currentCallActivity else {
            isInCall = false
            callApp = nil
            callStartTime = nil
            return
        }
        
        print("📞 Call terminata su \(callApp ?? "unknown")")
        
        let now = Date()
        activity.endTime = now
        if let startTime = callStartTime {
            activity.durationSeconds = Int(now.timeIntervalSince(startTime))
        }
        activity.updatedAt = now
        
        db.updateActivity(activity)
        
        isInCall = false
        callApp = nil
        callStartTime = nil
        currentCallActivity = nil
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
        return TimeInterval(idleTime) / 1_000_000_000.0
    }
}


