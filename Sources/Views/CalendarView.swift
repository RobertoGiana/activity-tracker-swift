import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: ActivityStore
    @State private var editingStartTime: String = ""
    @State private var editingVacationHours: Int = 0
    @State private var showStartTimeEditor: Bool = false
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header mese
            monthHeader
            
            HStack(alignment: .top, spacing: 20) {
                // Calendario
                calendarGrid
                    .frame(maxWidth: 540)
                
                // Dettagli giorno selezionato
                dayDetailView
            }
            .padding()
        }
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            Button(action: { store.changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(monthYearString)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: { store.changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Legenda
            legendView
            
            Divider()
            
            // Header giorni settimana
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(day == "Sab" || day == "Dom" ? .orange : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Griglia calendario
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            data: dayData(for: date),
                            isSelected: isSameDay(date, store.selectedDate),
                            isToday: isSameDay(date, Date())
                        )
                        .onTapGesture {
                            store.selectDate(date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 70)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Statistiche mese - Timesheet
            monthTimesheetView
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Legend
    
    private var legendView: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle().fill(Color.blue).frame(width: 8, height: 8)
                Text("Lavoro").font(.caption2).foregroundColor(.secondary)
            }
            HStack(spacing: 4) {
                Circle().fill(Color.orange).frame(width: 8, height: 8)
                Text("Straord.").font(.caption2).foregroundColor(.secondary)
            }
            HStack(spacing: 4) {
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Text("Festivo").font(.caption2).foregroundColor(.secondary)
            }
            HStack(spacing: 4) {
                Circle().fill(Color.yellow).frame(width: 8, height: 8)
                Text("Ferie").font(.caption2).foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Day Detail
    
    private var dayDetailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header giorno
            HStack {
                Text(formattedSelectedDate)
                    .font(.headline)
                
                Spacer()
                
                dayBadges
            }
            
            // Info giorno speciale
            if let dayData = selectedDayData {
                specialDayInfo(for: dayData)
            }
            
            // Impostazioni giorno lavorativo (ora inizio, ferie)
            workDaySettings
            
            // Timesheet giornaliero
            if let dayData = selectedDayData, dayData.workSeconds > 0 || dayData.leisureSeconds > 0 {
                timesheetCard(for: dayData)
            }
            
            Divider()
            
            // Lista attività raggruppate
            Text("Attività")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if store.groupedActivities.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("Nessuna attività")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.groupedActivities) { group in
                            GroupedActivityRowView(group: group)
                                .onTapGesture {
                                    store.userStartedInteracting()
                                    if let firstActivity = group.activities.first {
                                        store.selectedActivity = firstActivity
                                    }
                                }
                        }
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            store.userStartedInteracting()
                        }
                )
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
    
    // MARK: - Work Day Settings
    
    @ViewBuilder
    private var workDaySettings: some View {
        if let dayData = selectedDayData, !dayData.isHoliday && !dayData.isWeekend {
            VStack(spacing: 12) {
                // Ora di inizio
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    Text("Inizio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Mostra ora effettiva
                    if let startTime = dayData.effectiveStartTime {
                        let formatter = DateFormatter()
                        let _ = formatter.dateFormat = "HH:mm"
                        Text(formatter.string(from: startTime))
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                    
                    // Pulsante modifica
                    Button {
                        // Imposta valore iniziale
                        if let customStart = dayData.workDay?.customStartTime {
                            editingStartTime = customStart
                        } else if let startTime = dayData.startTime {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "HH:mm"
                            editingStartTime = formatter.string(from: startTime)
                        } else {
                            editingStartTime = "09:00"
                        }
                        showStartTimeEditor = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showStartTimeEditor) {
                        startTimeEditorPopover
                    }
                }
                
                // Ora fine standard
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.gray)
                    Text("Fine standard")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let endTime = dayData.standardEndTime {
                        let formatter = DateFormatter()
                        let _ = formatter.dateFormat = "HH:mm"
                        Text(formatter.string(from: endTime))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Ferie parziali
                HStack {
                    Image(systemName: "sun.max")
                        .foregroundColor(.yellow)
                    Text("Ferie (ore)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Picker("", selection: Binding(
                        get: { dayData.vacationHours },
                        set: { newValue in
                            store.saveWorkDay(
                                date: store.selectedDate,
                                customStartTime: dayData.workDay?.customStartTime,
                                vacationHours: newValue
                            )
                        }
                    )) {
                        ForEach(0...8, id: \.self) { hours in
                            Text("\(hours)h").tag(hours)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 70)
                }
                
                // Ferie giorno intero
                let isFullDayOff = dayData.dayOff != nil
                Button {
                    if isFullDayOff {
                        store.removeDayOff(date: store.selectedDate)
                    } else {
                        store.addDayOff(date: store.selectedDate, type: .vacation)
                    }
                } label: {
                    HStack {
                        Image(systemName: isFullDayOff ? "sun.max.fill" : "sun.max")
                        Text(isFullDayOff ? "Rimuovi Ferie Giorno" : "Ferie Giorno Intero")
                            .font(.caption)
                        Spacer()
                        if isFullDayOff {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(8)
                    .background(isFullDayOff ? Color.yellow.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                    .foregroundColor(isFullDayOff ? .yellow : .primary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Start Time Editor Popover
    
    private var startTimeEditorPopover: some View {
        VStack(spacing: 12) {
            Text("Ora di inizio")
                .font(.headline)
            
            TextField("HH:mm", text: $editingStartTime)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            
            HStack {
                Button("Annulla") {
                    showStartTimeEditor = false
                }
                
                Button("Auto") {
                    // Rimuove ora personalizzata, usa prima attività
                    store.saveWorkDay(
                        date: store.selectedDate,
                        customStartTime: nil,
                        vacationHours: selectedDayData?.vacationHours ?? 0
                    )
                    showStartTimeEditor = false
                }
                
                Button("Salva") {
                    // Valida formato HH:mm
                    let parts = editingStartTime.components(separatedBy: ":")
                    if parts.count == 2,
                       let hour = Int(parts[0]), hour >= 0 && hour <= 23,
                       let minute = Int(parts[1]), minute >= 0 && minute <= 59 {
                        store.saveWorkDay(
                            date: store.selectedDate,
                            customStartTime: editingStartTime,
                            vacationHours: selectedDayData?.vacationHours ?? 0
                        )
                    }
                    showStartTimeEditor = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    // MARK: - Day Badges
    
    @ViewBuilder
    private var dayBadges: some View {
        HStack(spacing: 4) {
            if let dayData = selectedDayData {
                if dayData.isHoliday {
                    Text("🎉 Festivo")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
                
                if dayData.dayOff != nil {
                    Text("🌞 Ferie")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                if dayData.isWeekend && !dayData.isHoliday && dayData.dayOff == nil {
                    Text("Weekend")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
        }
    }
    
    // MARK: - Special Day Info
    
    @ViewBuilder
    private func specialDayInfo(for dayData: CalendarDayData) -> some View {
        if let holidayName = dayData.holidayName {
            HStack {
                Image(systemName: "party.popper.fill")
                    .foregroundColor(.red)
                Text(holidayName)
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Timesheet Card
    
    private func timesheetCard(for data: CalendarDayData) -> some View {
        VStack(spacing: 12) {
            // Grafico a barre orario
            if !data.activities.isEmpty {
                HourlyActivityChart(data: data)
            }
            
            // Presenza effettiva (somma attività, escluso schermo bloccato)
            if data.calculatedPresenceSeconds > 0 {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.purple)
                    
                    Text("Tempo attivo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatHoursMinutes(data.calculatedPresenceSeconds))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }
            
            Divider()
            
            // Ore lavorate effettive
            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(.blue)
                
                Text("Lavoro tracciato")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(data.formattedWorkHours)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            
            // Ore standard (per giorni lavorativi)
            if data.isWorkingDay && !data.isNightWork {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.gray)
                    
                    let standardHours = (8 - data.vacationHours)
                    let label = data.vacationHours > 0 ? "Standard (\(standardHours)h + \(data.vacationHours)h ferie)" : "Standard (8h)"
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("✓ Considerato")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            // Lavoro notturno warning
            if data.isNightWork && !data.hasNightTailAndDaytimeWork {
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.purple)
                    
                    Text("Lavoro notturno")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Tutto straordinario")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Coda notturna + lavoro diurno
            if data.hasNightTailAndDaytimeWork {
                HStack {
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(.purple)
                    
                    Text("Coda notturna (da ieri)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Straordinario")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            // Straordinari
            if data.overtimeSeconds > 0 {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    
                    Text(overtimeLabel(for: data))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(data.formattedOvertimeHours)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
            
            // Svago
            if data.leisureSeconds > 0 {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundColor(.green)
                    
                    Text("Svago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatHM(data.leisureSeconds))
                        .font(.subheadline)
                        .monospacedDigit()
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Month Timesheet Stats
    
    private var monthTimesheetView: some View {
        let stats = monthTimesheetStats
        
        return VStack(spacing: 8) {
            Text("Riepilogo Mese")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                // Ore lavorate
                VStack(spacing: 2) {
                    Text(formatHM(stats.totalWork))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Lavoro")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                // Ore standard
                VStack(spacing: 2) {
                    Text(formatHM(stats.totalStandard))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Text("Standard")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                // Straordinari
                VStack(spacing: 2) {
                    Text(formatHM(stats.totalOvertime))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Straord.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                // Bilancio
                VStack(spacing: 2) {
                    let diff = stats.totalWork - stats.totalStandard
                    Text(diff >= 0 ? "+\(formatHM(diff))" : formatHM(diff))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(diff >= 0 ? .green : .red)
                    Text("Bilancio")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                // Giorni ferie
                VStack(spacing: 2) {
                    Text("\(stats.daysOff)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    Text("Ferie")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var selectedDayData: CalendarDayData? {
        store.calendarData.first { isSameDay($0.date, store.selectedDate) }
    }
    
    private var monthTimesheetStats: (totalWork: Int, totalStandard: Int, totalOvertime: Int, daysOff: Int) {
        var totalWork = 0
        var totalStandard = 0
        var totalOvertime = 0
        var daysOff = 0
        
        for day in store.calendarData {
            totalWork += day.workSeconds
            totalStandard += day.standardWorkSeconds
            totalOvertime += day.roundedOvertimeSeconds
            if day.dayOff != nil {
                daysOff += 1
            }
        }
        
        return (totalWork, totalStandard, totalOvertime, daysOff)
    }
    
    private func formatHM(_ seconds: Int) -> String {
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds < 0 ? "-" : ""
        return String(format: "%@%dh %02dm", sign, hours, minutes)
    }
    
    private func overtimeLabel(for data: CalendarDayData) -> String {
        if !data.isWorkingDay {
            return "Straordinario (\(data.specialDayDescription ?? ""))"
        } else if data.hasNightTailAndDaytimeWork {
            return "Straordinario (coda notturna + extra)"
        } else if data.isNightWork {
            return "Straordinario (notturno)"
        }
        return "Straordinario"
    }
    
    private func formatHoursMinutes(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: store.currentMonth).capitalized
    }
    
    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: store.selectedDate).capitalized
    }
    
    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: store.currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        var days: [Date?] = []
        var currentDate = monthFirstWeek.start
        
        // Aggiungi giorni vuoti per allineare al lunedì
        let weekday = calendar.component(.weekday, from: currentDate)
        let offset = (weekday + 5) % 7 // Converti da domenica=1 a lunedì=0
        
        for _ in 0..<offset {
            days.append(nil)
        }
        
        // Aggiungi giorni del mese
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return days
    }
    
    private func dayData(for date: Date) -> CalendarDayData? {
        store.calendarData.first { isSameDay($0.date, date) }
    }
    
    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        Calendar.current.isDate(date1, inSameDayAs: date2)
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let data: CalendarDayData?
    let isSelected: Bool
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(textColor)
            
            // Indicatori
            HStack(spacing: 2) {
                if data?.isHoliday == true {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                }
                
                if data?.dayOff != nil {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 6)
                }
            }
            
            if let data = data, data.workSeconds > 0 {
                // Indicatore ore lavoro
                VStack(spacing: 2) {
                    // Barra lavoro regolare
                    if data.regularWorkSeconds > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: CGFloat(min(data.regularWorkSeconds / 3600, 8)) * 4 + 4, height: 3)
                    }
                    
                    // Barra straordinario
                    if data.overtimeSeconds > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange)
                            .frame(width: CGFloat(min(data.overtimeSeconds / 3600, 8)) * 4 + 4, height: 3)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle()) // Rende cliccabile tutto il riquadro
    }
    
    private var textColor: Color {
        if data?.isHoliday == true {
            return .red
        } else if data?.dayOff != nil {
            return .yellow
        } else if data?.isWeekend == true {
            return .orange
        }
        return .primary
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isToday {
            return Color(NSColor.controlBackgroundColor)
        } else if data?.isHoliday == true {
            return Color.red.opacity(0.05)
        } else if data?.dayOff != nil {
            return Color.yellow.opacity(0.08)
        } else if data?.isWeekend == true {
            return Color.orange.opacity(0.05)
        } else {
            return Color.clear
        }
    }
}

struct MiniStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Hourly Activity Chart

struct HourlyActivityChart: View {
    let data: CalendarDayData
    
    /// Secondi per ora (0-23) suddivisi per categoria
    private var hourlyBuckets: [(work: Int, leisure: Int, overtime: Int)] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: data.date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let standardEnd = data.standardEndTime
        let hasNightTail = data.hasNightTailAndDaytimeWork
        
        // Soglia 5:00 per coda notturna
        var fiveAMComponents = calendar.dateComponents([.year, .month, .day], from: data.date)
        fiveAMComponents.hour = 5
        fiveAMComponents.minute = 0
        let fiveAM = calendar.date(from: fiveAMComponents) ?? dayEnd
        
        var buckets = Array(repeating: (work: 0, leisure: 0, overtime: 0), count: 24)
        
        for activity in data.activities {
            if CalendarDayData.isSystemActivity(activity) { continue }
            // Escludi call in background (tracciate in parallelo dal CallDetector)
            if activity.activityName.lowercased().contains("call -") { continue }
            
            let actEnd: Date
            if let end = activity.endTime {
                actEnd = min(end, dayEnd)
            } else if calendar.isDateInToday(data.date) {
                actEnd = Date()
            } else {
                continue
            }
            
            let actStart = max(activity.startTime, dayStart)
            guard actEnd > actStart else { continue }
            
            // Distribuisci i secondi nelle ore
            var cursor = actStart
            while cursor < actEnd {
                let hour = calendar.component(.hour, from: cursor)
                let nextHour = calendar.date(bySettingHour: hour + 1, minute: 0, second: 0, of: cursor) ?? dayEnd
                let sliceEnd = min(actEnd, min(nextHour, dayEnd))
                let secs = Int(sliceEnd.timeIntervalSince(cursor))
                
                if secs > 0 {
                    let cat = activity.category ?? .untracked
                    if cat == .work {
                        let isOvertime: Bool
                        if !data.isWorkingDay {
                            // Weekend/festivo/ferie: tutto straordinario
                            isOvertime = true
                        } else if hasNightTail && cursor < fiveAM {
                            // Coda notturna (0-5): straordinario
                            isOvertime = true
                        } else if !hasNightTail && data.isNightWork {
                            // Lavoro puramente notturno: tutto straordinario
                            isOvertime = true
                        } else if let se = standardEnd, cursor >= se {
                            // Dopo fine standard: straordinario
                            isOvertime = true
                        } else {
                            isOvertime = false
                        }
                        if isOvertime {
                            buckets[hour].overtime += secs
                        } else {
                            buckets[hour].work += secs
                        }
                    } else if cat == .leisure {
                        buckets[hour].leisure += secs
                    }
                }
                
                cursor = sliceEnd
            }
        }
        
        return buckets
    }
    
    /// Range di ore da mostrare (dalla prima alla ultima con attività)
    private var visibleRange: ClosedRange<Int> {
        let buckets = hourlyBuckets
        var first = 0
        var last = 23
        for i in 0..<24 {
            if buckets[i].work > 0 || buckets[i].leisure > 0 || buckets[i].overtime > 0 {
                first = i
                break
            }
        }
        for i in stride(from: 23, through: 0, by: -1) {
            if buckets[i].work > 0 || buckets[i].leisure > 0 || buckets[i].overtime > 0 {
                last = i
                break
            }
        }
        // Almeno 1 ora di padding
        let lo = max(0, first - 1)
        let hi = min(23, last + 1)
        return lo...hi
    }
    
    var body: some View {
        let buckets = hourlyBuckets
        let range = visibleRange
        let maxSecs = max(1, buckets[range].map { $0.work + $0.leisure + $0.overtime }.max() ?? 1)
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.gray)
                Text("Distribuzione oraria")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Range testuale compatto
                if let r = data.presenceRange {
                    let fmt = DateFormatter()
                    let _ = fmt.dateFormat = "HH:mm"
                    Text("\(fmt.string(from: r.start)) → \(fmt.string(from: r.end))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            
            // Barre
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(range), id: \.self) { hour in
                    let b = buckets[hour]
                    let total = b.work + b.leisure + b.overtime
                    let barHeight: CGFloat = total > 0 ? max(2, CGFloat(total) / CGFloat(maxSecs) * 32) : 0
                    
                    VStack(spacing: 0) {
                        // Barra stacked
                        if total > 0 {
                            VStack(spacing: 0) {
                                if b.overtime > 0 {
                                    Rectangle()
                                        .fill(Color.orange)
                                        .frame(height: barHeight * CGFloat(b.overtime) / CGFloat(total))
                                }
                                if b.leisure > 0 {
                                    Rectangle()
                                        .fill(Color.green)
                                        .frame(height: barHeight * CGFloat(b.leisure) / CGFloat(total))
                                }
                                if b.work > 0 {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(height: barHeight * CGFloat(b.work) / CGFloat(total))
                                }
                            }
                            .frame(height: barHeight)
                            .cornerRadius(1)
                        } else {
                            Spacer()
                                .frame(height: 0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32, alignment: .bottom)
                }
            }
            .frame(height: 32)
            
            // Etichette ore
            HStack(spacing: 1) {
                ForEach(Array(range), id: \.self) { hour in
                    Text("\(hour)")
                        .font(.system(size: 7))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#Preview {
    CalendarView()
        .environmentObject(ActivityStore.shared)
}




