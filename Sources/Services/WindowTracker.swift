import Foundation
import AppKit
import ApplicationServices

/// Informazioni sulla finestra attiva
struct WindowInfo: Equatable {
    let appName: String
    let appBundleId: String
    let windowTitle: String
    let activityName: String
}

/// Servizio per tracciare la finestra attiva
class WindowTracker {
    static let shared = WindowTracker()
    
    private init() {}
    
    /// Ottiene informazioni sulla finestra attualmente attiva
    func getActiveWindow() -> WindowInfo? {
        guard PermissionsService.shared.hasAccessibilityPermissions else {
            print("⚠️ Permessi Accessibility non concessi")
            return nil
        }
        
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        let appName = frontApp.localizedName ?? "Unknown"
        let appBundleId = frontApp.bundleIdentifier ?? "unknown"
        
        // Ottieni il titolo della finestra usando Accessibility API
        let windowTitle = getWindowTitle(for: frontApp) ?? ""
        
        // Estrai il nome dell'attività
        let activityName = extractActivityName(
            appName: appName,
            appBundleId: appBundleId,
            windowTitle: windowTitle
        )
        
        return WindowInfo(
            appName: appName,
            appBundleId: appBundleId,
            windowTitle: windowTitle,
            activityName: activityName
        )
    }
    
    /// Ottiene il titolo della finestra usando Accessibility API
    private func getWindowTitle(for app: NSRunningApplication) -> String? {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        guard result == .success, let window = focusedWindow else {
            return nil
        }
        
        var title: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)
        
        guard titleResult == .success, let windowTitle = title as? String else {
            return nil
        }
        
        return windowTitle
    }
    
    /// Estrae il nome dell'attività dal titolo della finestra in base all'app
    private func extractActivityName(appName: String, appBundleId: String, windowTitle: String) -> String {
        // Chrome/Chromium
        if appBundleId.contains("com.google.Chrome") || appBundleId.contains("com.chromium") {
            return extractChromeActivity(windowTitle)
        }
        
        // Safari
        if appBundleId.contains("com.apple.Safari") {
            return extractSafariActivity(windowTitle)
        }
        
        // Cursor
        if appBundleId.contains("com.todesktop.230313mzl4w4u92") {
            return extractCursorActivity(windowTitle)
        }
        
        // VS Code
        if appBundleId.contains("com.microsoft.VSCode") {
            return extractVSCodeActivity(windowTitle)
        }
        
        // IntelliJ IDEA
        if appBundleId.contains("com.jetbrains") {
            return extractIntelliJActivity(windowTitle)
        }
        
        // Xcode
        if appBundleId.contains("com.apple.dt.Xcode") {
            return extractXcodeActivity(windowTitle)
        }
        
        // Fallback: usa il titolo della finestra o il nome dell'app
        return windowTitle.isEmpty ? appName : windowTitle
    }
    
    // MARK: - Extraction per App Specifiche
    
    private func extractChromeActivity(_ windowTitle: String) -> String {
        // Chrome mostra "Titolo - Google Chrome"
        // Prova a estrarre URL se presente
        if let urlMatch = windowTitle.range(of: #"https?://[^\s-]+"#, options: .regularExpression) {
            return String(windowTitle[urlMatch])
        }
        
        // Rimuovi il suffisso "- Google Chrome"
        return windowTitle
            .replacingOccurrences(of: #"\s*-\s*(Google\s+)?Chrome.*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func extractSafariActivity(_ windowTitle: String) -> String {
        // Safari mostra "Titolo — App Name" o URL
        return windowTitle
            .replacingOccurrences(of: #"\s*[—–-]\s*Safari.*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func extractCursorActivity(_ windowTitle: String) -> String {
        // Cursor mostra "file.ts - progetto - Cursor"
        if let match = windowTitle.range(of: #"\s*-\s*([^-]+)\s*-\s*Cursor$"#, options: .regularExpression) {
            let project = windowTitle[match]
                .replacingOccurrences(of: #"^\s*-\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*-\s*Cursor$"#, with: "", options: .regularExpression)
            return project.trimmingCharacters(in: .whitespaces)
        }
        
        // Estrai solo il nome del file
        if let fileMatch = windowTitle.range(of: #"^[^-]+"#, options: .regularExpression) {
            return String(windowTitle[fileMatch]).trimmingCharacters(in: .whitespaces)
        }
        
        return windowTitle
    }
    
    private func extractVSCodeActivity(_ windowTitle: String) -> String {
        // VS Code mostra "file - progetto - Visual Studio Code"
        if let match = windowTitle.range(of: #"\s*-\s*([^-]+)\s*-\s*Visual Studio Code"#, options: .regularExpression) {
            let project = windowTitle[match]
                .replacingOccurrences(of: #"^\s*-\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*-\s*Visual Studio Code$"#, with: "", options: .regularExpression)
            return project.trimmingCharacters(in: .whitespaces)
        }
        
        return windowTitle
    }
    
    private func extractIntelliJActivity(_ windowTitle: String) -> String {
        // IntelliJ mostra "file - progetto - IntelliJ IDEA"
        if let match = windowTitle.range(of: #"\s*-\s*([^-]+)\s*-\s*IntelliJ"#, options: .regularExpression) {
            let project = windowTitle[match]
                .replacingOccurrences(of: #"^\s*-\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*-\s*IntelliJ.*$"#, with: "", options: .regularExpression)
            return project.trimmingCharacters(in: .whitespaces)
        }
        
        return windowTitle
    }
    
    private func extractXcodeActivity(_ windowTitle: String) -> String {
        // Xcode mostra "Progetto — File.swift"
        if let dashIndex = windowTitle.firstIndex(of: "—") ?? windowTitle.firstIndex(of: "-") {
            let project = windowTitle[..<dashIndex].trimmingCharacters(in: .whitespaces)
            return project
        }
        
        return windowTitle
    }
}




