import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ActivityStore
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab {
        case dashboard
        case calendar
        case patterns
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedTab) {
                Section("Principale") {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                        .tag(Tab.dashboard)
                    
                    Label("Calendario", systemImage: "calendar")
                        .tag(Tab.calendar)
                }
                
                Section("Impostazioni") {
                    Label("Pattern", systemImage: "doc.text.magnifyingglass")
                        .tag(Tab.patterns)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            // Content
            switch selectedTab {
            case .dashboard:
                DashboardView()
            case .calendar:
                CalendarView()
            case .patterns:
                PatternListView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    ContentView()
        .environmentObject(ActivityStore.shared)
}




