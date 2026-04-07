import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: ActivityStore
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            HStack(spacing: 20) {
                // Statistiche
                statsView
                    .frame(width: 280)
                
                // Lista attività
                activityListView
            }
            .padding()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Activity Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status monitoraggio
            HStack(spacing: 8) {
                Circle()
                    .fill(ActivityMonitor.shared.isMonitoring ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(ActivityMonitor.shared.isMonitoring ? "Monitoraggio attivo" : "Monitoraggio disattivo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(16)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Stats
    
    private var statsView: some View {
        VStack(spacing: 16) {
            // Statistiche giornaliere
            VStack(alignment: .leading, spacing: 12) {
                Text("Oggi")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                StatCard(
                    title: "Lavoro",
                    value: store.formatDuration(store.todayStats.work),
                    icon: "briefcase.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Svago",
                    value: store.formatDuration(store.todayStats.leisure),
                    icon: "gamecontroller.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Totale",
                    value: store.formatDuration(store.todayStats.total),
                    icon: "clock.fill",
                    color: .purple
                )
            }
            
            Divider()
            
            // Attività corrente
            if let current = ActivityMonitor.shared.currentActivity {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attività corrente")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    CurrentActivityCard(activity: current)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Activity List
    
    private var activityListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Attività di oggi")
                    .font(.headline)
                
                Spacer()
                
                Text("\(store.activities.count) attività")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if store.groupedActivities.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.groupedActivities) { group in
                            GroupedActivityRowView(group: group)
                                .onTapGesture {
                                    if let firstActivity = group.activities.first {
                                        store.selectedActivity = firstActivity
                                    }
                                }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .sheet(item: $store.selectedActivity) { activity in
            ClassificationSheet(activity: activity)
                .environmentObject(store)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Nessuna attività registrata")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Le attività appariranno qui quando inizierai a lavorare")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helpers
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return formatter.string(from: store.selectedDate).capitalized
    }
}

// MARK: - Subviews

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}

struct CurrentActivityCard: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: 12) {
            // Indicatore pulsante
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.green.opacity(0.5), lineWidth: 2)
                        .scaleEffect(1.5)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(activity.appName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(activity.formattedDuration)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}

struct GroupedActivityRowView: View {
    let group: GroupedActivity
    
    var body: some View {
        HStack(spacing: 12) {
            // Icona categoria
            Circle()
                .fill(categoryColor)
                .frame(width: 10, height: 10)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(group.appName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let category = group.category {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(category.displayName)
                            .font(.caption)
                            .foregroundColor(categoryColor)
                    }
                    
                    if group.count > 1 {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(group.count) sessioni")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Tempo totale
            VStack(alignment: .trailing, spacing: 2) {
                Text(group.formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                
                Text(formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
    
    private var categoryColor: Color {
        switch group.category {
        case .work: return .blue
        case .leisure: return .green
        case .untracked: return .gray
        case nil: return .gray
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: group.lastStartTime)
    }
}

struct ActivityRowView: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: 12) {
            // Icona categoria
            Circle()
                .fill(categoryColor)
                .frame(width: 8, height: 8)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(activity.appName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let category = activity.category {
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(category.displayName)
                            .font(.caption)
                            .foregroundColor(categoryColor)
                    }
                }
            }
            
            Spacer()
            
            // Tempo
            VStack(alignment: .trailing, spacing: 2) {
                Text(activity.formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                
                Text(formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
    
    private var categoryColor: Color {
        switch activity.category {
        case .work: return .blue
        case .leisure: return .green
        case .untracked: return .gray
        case nil: return .gray
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: activity.startTime)
    }
}

#Preview {
    DashboardView()
        .environmentObject(ActivityStore.shared)
}




