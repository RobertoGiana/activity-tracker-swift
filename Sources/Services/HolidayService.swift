import Foundation

/// Servizio per la gestione dei festivi italiani
struct HolidayService {
    
    /// Festivi italiani fissi
    static let fixedHolidays: [(month: Int, day: Int, name: String)] = [
        (1, 1, "Capodanno"),
        (1, 6, "Epifania"),
        (4, 25, "Festa della Liberazione"),
        (5, 1, "Festa dei Lavoratori"),
        (6, 2, "Festa della Repubblica"),
        (8, 15, "Ferragosto"),
        (11, 1, "Tutti i Santi"),
        (12, 8, "Immacolata Concezione"),
        (12, 25, "Natale"),
        (12, 26, "Santo Stefano"),
    ]
    
    /// Calcola la Pasqua per un anno specifico (algoritmo di Gauss)
    static func easterDate(year: Int) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        
        return Calendar.current.date(from: components) ?? Date()
    }
    
    /// Pasquetta (Lunedì dell'Angelo) - giorno dopo Pasqua
    static func easterMondayDate(year: Int) -> Date {
        let easter = easterDate(year: year)
        return Calendar.current.date(byAdding: .day, value: 1, to: easter) ?? easter
    }
    
    /// Verifica se una data è un festivo italiano
    static func isHoliday(_ date: Date) -> (isHoliday: Bool, name: String?) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return (false, nil)
        }
        
        // Controlla festivi fissi
        for holiday in fixedHolidays {
            if holiday.month == month && holiday.day == day {
                return (true, holiday.name)
            }
        }
        
        // Controlla Pasqua
        let easter = easterDate(year: year)
        if calendar.isDate(date, inSameDayAs: easter) {
            return (true, "Pasqua")
        }
        
        // Controlla Pasquetta
        let easterMonday = easterMondayDate(year: year)
        if calendar.isDate(date, inSameDayAs: easterMonday) {
            return (true, "Pasquetta")
        }
        
        return (false, nil)
    }
    
    /// Ottiene tutti i festivi per un anno
    static func holidaysForYear(_ year: Int) -> [(date: Date, name: String)] {
        var holidays: [(date: Date, name: String)] = []
        let calendar = Calendar.current
        
        // Aggiungi festivi fissi
        for holiday in fixedHolidays {
            var components = DateComponents()
            components.year = year
            components.month = holiday.month
            components.day = holiday.day
            
            if let date = calendar.date(from: components) {
                holidays.append((date, holiday.name))
            }
        }
        
        // Aggiungi Pasqua e Pasquetta
        let easter = easterDate(year: year)
        holidays.append((easter, "Pasqua"))
        holidays.append((easterMondayDate(year: year), "Pasquetta"))
        
        return holidays.sorted { $0.date < $1.date }
    }
}

/// Tipo di giorno speciale (solo ferie per ora)
enum DayOffType: String, CaseIterable, Codable {
    case vacation = "ferie"
    
    var displayName: String {
        return "Ferie"
    }
    
    var icon: String {
        return "sun.max.fill"
    }
}

/// Giorno di assenza/ferie
struct DayOff: Identifiable, Equatable {
    let id: Int64?
    let date: Date
    let type: DayOffType
    let note: String?
    
    init(id: Int64? = nil, date: Date, type: DayOffType, note: String? = nil) {
        self.id = id
        self.date = date
        self.type = type
        self.note = note
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

/// Personalizzazioni per un giorno lavorativo
struct WorkDay: Identifiable, Equatable {
    let id: Int64?
    let date: Date
    var customStartTime: String? // Formato "HH:mm", nil = usa prima attività
    var vacationHours: Int // 0-8 ore di ferie parziali
    var notes: String?
    
    init(id: Int64? = nil, date: Date, customStartTime: String? = nil, vacationHours: Int = 0, notes: String? = nil) {
        self.id = id
        self.date = date
        self.customStartTime = customStartTime
        self.vacationHours = min(8, max(0, vacationHours))
        self.notes = notes
    }
    
    /// Ora inizio come Date (nel giorno specificato)
    func startTimeAsDate() -> Date? {
        guard let timeStr = customStartTime else { return nil }
        let parts = timeStr.components(separatedBy: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        
        let calendar = Calendar.current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }
    
    /// Ore lavorative standard (8 - ore ferie)
    var standardHours: Int {
        return max(0, 8 - vacationHours)
    }
}




