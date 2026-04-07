import Foundation
import AppKit
import ApplicationServices

/// Servizio per la gestione dei permessi macOS
class PermissionsService {
    static let shared = PermissionsService()
    
    private init() {}
    
    /// Verifica se i permessi di Accessibility sono stati concessi
    var hasAccessibilityPermissions: Bool {
        AXIsProcessTrusted()
    }
    
    /// Richiede i permessi di Accessibility
    func requestAccessibilityPermissions() {
        if !hasAccessibilityPermissions {
            print("⚠️ Richiesta permessi Accessibility...")
            
            // Mostra il prompt di sistema per i permessi
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
            
            print("📋 Vai in Preferenze di Sistema > Privacy e Sicurezza > Accessibilità")
            print("   e abilita Activity Tracker")
        } else {
            print("✅ Permessi Accessibility già concessi")
        }
    }
    
    /// Apre le preferenze di sistema alla sezione Accessibility
    func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}




