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
    static let accent = Color(red: 0x00/255, green: 0xF5/255, blue: 0xA0/255)   // electric neon mint (#00F5A0)
    static let cyan = Color(red: 0x00/255, green: 0xD2/255, blue: 0xC4/255)     // neon cyan (#00D2C4)
    static let pink = Color(red: 1.0, green: 0.18, blue: 0.58)
    static let blue = Color(red: 0.20, green: 0.50, blue: 1.0)
    static let green = Color(red: 0x00/255, green: 0xF5/255, blue: 0xA0/255)
    static let warn = Color(red: 0xF9/255, green: 0x73/255, blue: 0x16/255)     // neon coral (#F97316)
    static let purple = Color(red: 0x7C/255, green: 0x3A/255, blue: 0xED/255)   // neon purple (#7C3AED)
    static let bg = Color(red: 0x0B/255, green: 0x11/255, blue: 0x18/255)       // deep navy canvas (#0B1118)
    static let card = Color(red: 0x12/255, green: 0x1B/255, blue: 0x26/255)     // dark card (#121B26)
    static let cardBorder = Color(red: 0x1D/255, green: 0x2D/255, blue: 0x40/255) // border stroke (#1D2D40)
    static let cardSubtle = Color(red: 0x1A/255, green: 0x28/255, blue: 0x38/255)
    static let mintGradient = LinearGradient(colors: [accent, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct RadialProgressGauge: View {
    var percent: Double
    var title: String = "ALLOCATED"
    var lineWidth: CGFloat = 8
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.cardBorder, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(percent, 0.0), 1.0)))
                .stroke(Theme.mintGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: percent)
            VStack(spacing: 2) {
                Text("\(Int(percent * 100))%")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension View {
    /// Plain list on a grouped background, ready for card rows.
    func cardList() -> some View {
        self.listStyle(.plain).scrollContentBackground(.hidden).background(Theme.bg)
    }
    /// Draws a list row as a rounded card matching reference design.
    func cardRow() -> some View {
        self.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.cardBorder, lineWidth: 1)
                    )
                    .padding(.vertical, 3).padding(.horizontal, 16)
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
