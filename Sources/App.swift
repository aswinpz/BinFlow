import SwiftUI
import UniformTypeIdentifiers

@main
struct BinFlowApp: App {
    @State private var store = Store()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .onChange(of: phase) { _, new in
                    let auto = UserDefaults.standard.object(forKey: "autoReload") as? Bool ?? true
                    if new == .active && auto { store.refreshFromDisk() }
                }
        }
    }
}

enum Theme {
    static let accent = Color(red: 0.05, green: 0.80, blue: 0.90)   // neon cyan
    static let pink = Color(red: 1.0, green: 0.18, blue: 0.58)
    static let blue = Color(red: 0.20, green: 0.50, blue: 1.0)
    static let green = Color(red: 0.20, green: 0.95, blue: 0.55)
    static let warn = Color.orange
    static let bg = Color(red: 0.02, green: 0.02, blue: 0.04)
    static let card = Color(white: 0.09)
}

extension View {
    /// Plain list on a grouped background, ready for card rows.
    func cardList() -> some View {
        self.listStyle(.plain).scrollContentBackground(.hidden).background(Theme.bg)
    }
    /// Draws a list row as a rounded card.
    func cardRow() -> some View {
        self.listRowInsets(EdgeInsets(top: 10, leading: 30, bottom: 10, trailing: 26))
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card)
                    .padding(.vertical, 4).padding(.horizontal, 16)
            )
    }
    /// Transparent row for headers placed above card rows.
    func plainRow() -> some View {
        self.listRowBackground(Color.clear).listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

struct BinChip: View {
    let code: String
    var body: some View {
        Text(code)
            .font(.footnote.monospaced().weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(Theme.accent)
    }
}

struct StatusPill: View {
    let available: Bool
    var body: some View {
        Label(available ? "Available" : "Unavailable",
              systemImage: available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background((available ? Theme.accent : Theme.warn).opacity(0.15), in: Capsule())
            .foregroundStyle(available ? Theme.accent : Theme.warn)
    }
}

struct Tag: View {
    let text: String
    var body: some View {
        Text(text).font(.caption.weight(.medium))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
        Group {
            if store.hasFile { HomeView() } else { SetupView() }
        }
        .fileImporter(
            isPresented: Binding(get: { store.showPicker }, set: { store.showPicker = $0 }),
            allowedContentTypes: [UTType(filenameExtension: "xlsx") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls): if let u = urls.first { store.choose(u) }
            case .failure(let e): store.error = e.localizedDescription
            }
        }
        .alert("BinFlow", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.error ?? "")
        }
    }
}

struct SetupView: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(spacing: 18) {
            Image("Logo").resizable().scaledToFit().frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            Text("Connect your spreadsheet").font(.title2.bold())
            Text("Choose your Excel file (for example camper_master.xlsx). BinFlow reads Sheet1 and writes every change straight back into the same file.\n\nA SKU with an empty Bin cell shows as Unavailable.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button { store.showPicker = true } label: {
                Label("Choose Excel file", systemImage: "folder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).foregroundStyle(.black)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

/// Both stacks (Find and Bins) can open items and bins.
extension View {
    func binflowDestinations() -> some View {
        self
            .navigationDestination(for: String.self) { ItemDetail(sku: $0) }
            .navigationDestination(for: BinRef.self) { BinDetail(code: $0.code) }
    }
}
