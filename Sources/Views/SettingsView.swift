import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var store: ActivityStore
    @State private var showingResetConfirmation = false
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    
    var body: some View {
        Form {
            Section("Permessi") {
                HStack {
                    Label("Accessibilità", systemImage: "hand.raised.fill")
                    
                    Spacer()
                    
                    if PermissionsService.shared.hasAccessibilityPermissions {
                        Label("Attivo", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Richiedi") {
                            PermissionsService.shared.openAccessibilityPreferences()
                        }
                    }
                }
            }
            
            Section("Monitoraggio") {
                HStack {
                    Label("Stato", systemImage: "antenna.radiowaves.left.and.right")
                    
                    Spacer()
                    
                    if ActivityMonitor.shared.isMonitoring {
                        Text("Attivo")
                            .foregroundColor(.green)
                    } else {
                        Text("Disattivo")
                            .foregroundColor(.red)
                    }
                }
                
                Toggle("Avvia automaticamente al login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("❌ Errore impostazione avvio automatico: \(error)")
                            // Ripristina lo stato
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            
            Section("Dati") {
                LabeledContent("Attività totali", value: "\(DatabaseService.shared.totalActivityCount())")
                
                Button {
                    let deleted = DatabaseService.shared.purgeOldActivities(olderThanDays: 90)
                    if deleted > 0 {
                        store.refreshAll()
                    }
                } label: {
                    Label("Elimina attività > 90 giorni", systemImage: "clock.badge.xmark")
                }
                
                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Label("Resetta Database", systemImage: "trash")
                }
            }
            
            Section("Info") {
                LabeledContent("Versione", value: "1.0.0")
                LabeledContent("Build", value: "SwiftUI Native")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 420)
        .alert("Resetta Database", isPresented: $showingResetConfirmation) {
            Button("Annulla", role: .cancel) {}
            Button("Resetta", role: .destructive) {
                DatabaseService.shared.resetDatabase()
                store.refreshAll()
            }
        } message: {
            Text("Tutti i dati delle attività verranno eliminati. Questa azione non può essere annullata.")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ActivityStore.shared)
}




