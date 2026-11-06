import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @AppStorage("userName") private var userName = "Aswin"
    @AppStorage("autoReload") private var autoReload = true
    @AppStorage("haptics") private var haptics = true
    @State private var confirmDisconnect = false
    @State private var confirmClearLog = false

    var body: some View {
        Form {
            Section {
                LabeledContent("File", value: store.fileName.isEmpty ? "None" : store.fileName)
                LabeledContent("Contents", value: "\(store.items.count) SKUs · \(store.allBins.count) bins")
                Button("Reload from file", systemImage: "arrow.clockwise") { store.reload() }
                Button("Choose a different Excel file", systemImage: "folder") { store.showPicker = true }
                if let url = store.fileURL { ShareLink("Share / back up a copy", item: url) }
                Toggle("Reload when app opens", isOn: $autoReload)
                Button("Disconnect file", systemImage: "link.badge.minus", role: .destructive) { confirmDisconnect = true }
            } header: { Text("Excel file") } footer: {
                Text("BinFlow reads Sheet1 and saves every change straight into this file. If Excel or another app edits it, reload to pick up the changes.")
            }

            Section {
                Toggle("Haptic feedback", isOn: $haptics)
            } header: { Text("Scanner") } footer: {
                Text("The camera reads text and finds a SKU printed on a label or box when it matches a SKU in your sheet. You can also tap any highlighted text to use it.")
            }

            Section("Profile") {
                TextField("Your name", text: $userName)
            }

            Section("Data") {
                Button("Clear activity log", systemImage: "trash", role: .destructive) { confirmClearLog = true }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("Settings")
        .confirmationDialog("Disconnect the spreadsheet?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) { store.disconnect() }
        } message: { Text("The file stays where it is. You'll be asked to choose a file again.") }
        .confirmationDialog("Clear the activity log?", isPresented: $confirmClearLog, titleVisibility: .visible) {
            Button("Clear log", role: .destructive) { store.clearLog() }
        }
    }
}
