import SwiftUI

struct PatternListView: View {
    @EnvironmentObject var store: ActivityStore
    @State private var showingAddPattern = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pattern di Classificazione")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("I pattern vengono usati per classificare automaticamente le attività simili")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingAddPattern = true }) {
                    Label("Aggiungi", systemImage: "plus")
                }
            }
            .padding()
            
            Divider()
            
            // Lista pattern
            if store.patterns.isEmpty && store.classifications.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Classificazioni
                        if !store.classifications.isEmpty {
                            Section {
                                ForEach(store.classifications) { classification in
                                    ClassificationRowView(classification: classification) {
                                        if let id = classification.id {
                                            store.deleteClassification(id)
                                        }
                                    }
                                }
                            } header: {
                                SectionHeader(title: "Classificazioni")
                            }
                        }
                        
                        // Pattern personalizzati
                        if !store.patterns.isEmpty {
                            Section {
                                ForEach(store.patterns) { pattern in
                                    PatternRowView(pattern: pattern) {
                                        if let id = pattern.id {
                                            store.deletePattern(id)
                                        }
                                    }
                                }
                            } header: {
                                SectionHeader(title: "Pattern Personalizzati")
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddPattern) {
            AddPatternSheet()
                .environmentObject(store)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Nessun pattern configurato")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("I pattern vengono creati automaticamente quando classifichi un'attività, oppure puoi aggiungerli manualmente")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Button(action: { showingAddPattern = true }) {
                Label("Aggiungi Pattern", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
}

struct ClassificationRowView: View {
    let classification: Classification
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(categoryColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(classification.pattern)
                    .font(.subheadline)
                    .lineLimit(2)
                
                HStack {
                    Text(classification.category.displayName)
                        .font(.caption)
                        .foregroundColor(categoryColor)
                    
                    if let name = classification.generalizedName {
                        Text("→ \(name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var categoryColor: Color {
        switch classification.category {
        case .work: return .blue
        case .leisure: return .green
        case .untracked: return .gray
        }
    }
}

struct PatternRowView: View {
    let pattern: Pattern
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.pattern)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack {
                    Text(pattern.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("→")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(pattern.replacement)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct AddPatternSheet: View {
    @EnvironmentObject var store: ActivityStore
    @Environment(\.dismiss) var dismiss
    
    @State private var patternType: Pattern.PatternType = .url
    @State private var patternValue: String = ""
    @State private var replacement: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Aggiungi Pattern")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tipo")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Tipo", selection: $patternType) {
                    ForEach(Pattern.PatternType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Pattern (testo da cercare)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("es. github.com, Visual Studio Code", text: $patternValue)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Sostituzione (nome generalizzato)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("es. GitHub, VS Code", text: $replacement)
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
            
            HStack {
                Button("Annulla") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Aggiungi") {
                    addPattern()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(patternValue.isEmpty || replacement.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 320)
    }
    
    private func addPattern() {
        let pattern = Pattern(
            type: patternType,
            pattern: patternValue,
            replacement: replacement
        )
        store.addPattern(pattern)
        dismiss()
    }
}

#Preview {
    PatternListView()
        .environmentObject(ActivityStore.shared)
}




