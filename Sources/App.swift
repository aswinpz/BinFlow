import SwiftUI
import UniformTypeIdentifiers

@main
struct BinFlowApp: App {
    @State private var store = Store()
    @Environment(\.scenePhase) private var phase
    @AppStorage("colorMode") private var colorMode = "dark"
    @AppStorage("colorTheme") private var colorTheme = "Mint"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.accent)
                .preferredColorScheme(colorMode == "light" ? .light : .dark)
                .onChange(of: phase) { _, new in
                    let auto = UserDefaults.standard.object(forKey: "autoReload") as? Bool ?? true
                    if new == .active && auto { store.refreshFromDisk() }
                }
        }
    }
}

enum Theme {
    private static var selected: String { UserDefaults.standard.string(forKey: "colorTheme") ?? "Mint" }
    private static var lightMode: Bool { UserDefaults.standard.string(forKey: "colorMode") == "light" }
    static var accent: Color {
        switch selected {
        case "Ocean": return Color(red: 0.12, green: 0.48, blue: 0.98)
        case "Sunset": return Color(red: 0.98, green: 0.30, blue: 0.20)
        case "Berry": return Color(red: 0.91, green: 0.20, blue: 0.56)
        case "Orchid": return Color(red: 0.60, green: 0.31, blue: 0.94)
        case "Forest": return Color(red: 0.08, green: 0.62, blue: 0.36)
        case "Amber": return Color(red: 0.92, green: 0.55, blue: 0.05)
        case "Rose": return Color(red: 0.88, green: 0.30, blue: 0.42)
        default: return Color(red: 0.00, green: 0.82, blue: 0.56)
        }
    }
    static var cyan: Color {
        switch selected {
        case "Ocean": return Color(red: 0.10, green: 0.78, blue: 0.91)
        case "Sunset": return Color(red: 1.00, green: 0.68, blue: 0.28)
        case "Berry": return Color(red: 1.00, green: 0.43, blue: 0.64)
        case "Orchid": return Color(red: 0.32, green: 0.64, blue: 1.00)
        case "Forest": return Color(red: 0.52, green: 0.81, blue: 0.31)
        case "Amber": return Color(red: 1.00, green: 0.78, blue: 0.20)
        case "Rose": return Color(red: 1.00, green: 0.60, blue: 0.54)
        default: return Color(red: 0.00, green: 0.70, blue: 0.73)
        }
    }
    static var pink: Color { Color(red: 0.95, green: 0.24, blue: 0.58) }
    static var blue: Color { Color(red: 0.20, green: 0.50, blue: 1.0) }
    static var green: Color { accent }
    static var warn: Color { Color(red: 0.95, green: 0.39, blue: 0.12) }
    static var purple: Color { Color(red: 0.49, green: 0.23, blue: 0.85) }
    static var bg: Color { lightMode ? Color(red: 0.96, green: 0.97, blue: 0.99) : Color(red: 0.04, green: 0.07, blue: 0.10) }
    static var card: Color { lightMode ? .white : Color(red: 0.08, green: 0.11, blue: 0.15) }
    static var cardBorder: Color { lightMode ? Color(red: 0.87, green: 0.89, blue: 0.93) : Color(red: 0.12, green: 0.18, blue: 0.24) }
    static var cardSubtle: Color { lightMode ? Color(red: 0.92, green: 0.94, blue: 0.97) : Color(red: 0.10, green: 0.15, blue: 0.20) }
    static var primaryText: Color { .primary }
    static var mintGradient: LinearGradient { LinearGradient(colors: [accent, cyan], startPoint: .topLeading, endPoint: .bottomTrailing) }
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
                    .foregroundStyle(Theme.primaryText)
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
    @AppStorage("colorTheme") private var colorTheme = "Mint"
    @AppStorage("colorMode") private var colorMode = "dark"

    var body: some View {
        let _ = colorTheme
        let _ = colorMode
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
        .alert("CAMPX DXB", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
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
            Text("Choose your Excel file (for example camper_master.xlsx). CAMPX DXB reads Sheet1 and writes every change straight back into the same file.\n\nA SKU with an empty Bin cell shows as Unavailable.")
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
