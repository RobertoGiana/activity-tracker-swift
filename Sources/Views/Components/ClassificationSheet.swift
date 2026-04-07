import SwiftUI
import AppKit

struct ClassificationSheet: View {
    @EnvironmentObject var store: ActivityStore
    @Environment(\.dismiss) var dismiss
    
    let activity: Activity
    
    @State private var selectedCategory: ActivityCategory = .work
    @State private var selectedTags: Set<String> = []
    @State private var classifyEntireApp: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Classifica Attività")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Info attività
            VStack(alignment: .leading, spacing: 8) {
                Text("Attività")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(activity.displayName)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Label(activity.appName, systemImage: "app.fill")
                    Spacer()
                    Label(activity.formattedDuration, systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Opzione: Classifica intera app
            Toggle(isOn: $classifyEntireApp) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Classifica tutta l'app \"\(activity.appName)\"")
                        .font(.subheadline)
                    Text("Applica questa categoria a tutte le attività di questa app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .padding(.vertical, 4)
            
            // Selezione categoria
            VStack(alignment: .leading, spacing: 8) {
                Text("Categoria")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    ForEach(ActivityCategory.allCases, id: \.self) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
            
            // Pattern builder con tag dal titolo
            VStack(alignment: .leading, spacing: 8) {
                Text("Pattern di riconoscimento")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Seleziona le parole chiave per raggruppare attività simili")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // Pattern risultante
                if !selectedTags.isEmpty {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.green)
                        Text(patternPreview)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // Tag estratti dal titolo
                ScrollView {
                    FlowLayout(spacing: 8) {
                        ForEach(extractedTags, id: \.self) { tag in
                            TagChip(
                                text: tag,
                                isSelected: selectedTags.contains(tag),
                                color: selectedTags.contains(tag) ? .green : .gray
                            ) {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 100)
                
                // Reset
                if !selectedTags.isEmpty {
                    Button {
                        selectedTags.removeAll()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset selezione")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // Bottoni
            HStack {
                Button("Annulla") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Salva") {
                    saveClassification()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500, height: 560)
        .onAppear {
            if let category = activity.category {
                selectedCategory = category
            }
            // Se c'è già un nome generalizzato, preseleziona quei tag
            if let existing = activity.generalizedName {
                let existingWords = Set(existing.components(separatedBy: " "))
                selectedTags = existingWords.intersection(Set(extractedTags))
            }
        }
    }
    
    // Estrai tag dal titolo dell'attività
    private var extractedTags: [String] {
        let title = activity.displayName
        
        // Separa per caratteri speciali comuni
        let separators = CharacterSet(charactersIn: " :|-–—•·/\\[](){}\"'.,;!?@#$%^&*+=<>~`")
        let words = title.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count > 1 } // Almeno 2 caratteri
        
        // Rimuovi duplicati mantenendo l'ordine
        var seen = Set<String>()
        var unique: [String] = []
        for word in words {
            let lower = word.lowercased()
            if !seen.contains(lower) {
                seen.insert(lower)
                unique.append(word)
            }
        }
        
        return unique
    }
    
    // Preview del pattern
    private var patternPreview: String {
        if selectedTags.isEmpty {
            return "*"
        }
        // Ordina i tag nell'ordine in cui appaiono nel titolo
        let orderedTags = extractedTags.filter { selectedTags.contains($0) }
        return orderedTags.joined(separator: " ")
    }
    
    // Nome generalizzato dai tag selezionati
    private var generalizedName: String? {
        if selectedTags.isEmpty {
            return nil
        }
        let orderedTags = extractedTags.filter { selectedTags.contains($0) }
        return orderedTags.joined(separator: " ")
    }
    
    private func saveClassification() {
        if classifyEntireApp {
            store.classifyApp(
                bundleId: activity.appBundleId,
                appName: activity.appName,
                category: selectedCategory,
                generalizedName: generalizedName
            )
        } else {
            store.classifyActivity(
                activity,
                category: selectedCategory,
                generalizedName: generalizedName
            )
        }
        dismiss()
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let text: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isSelected ? color : .primary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout per i tag

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

struct CategoryButton: View {
    let category: ActivityCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title2)
                
                Text(category.displayName)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? categoryColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? categoryColor : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? categoryColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var iconName: String {
        switch category {
        case .work: return "briefcase.fill"
        case .leisure: return "gamecontroller.fill"
        case .untracked: return "eye.slash.fill"
        }
    }
    
    private var categoryColor: Color {
        switch category {
        case .work: return .blue
        case .leisure: return .green
        case .untracked: return .gray
        }
    }
}

#Preview {
    ClassificationSheet(activity: Activity(
        appName: "Microsoft Teams",
        appBundleId: "com.microsoft.teams",
        windowTitle: "Chat | NRT 8.0.0 | Microsoft Teams",
        activityName: "Chat | NRT 8.0.0 | Microsoft Teams"
    ))
    .environmentObject(ActivityStore.shared)
}




