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
                .onChange(of: phase) { _, new in
                    if new == .active { store.refreshFromDisk() }
                }
        }
    }
}

enum Theme {
    static let accent = Color(red: 0.0, green: 0.46, blue: 0.43)
}

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
        Group {
            if store.hasFile {
                TabView {
                    FindView().tabItem { Label("Find", systemImage: "magnifyingglass") }
                    ReceiveView().tabItem { Label("Receive", systemImage: "shippingbox.and.arrow.backward") }
                    BinsView().tabItem { Label("Bins", systemImage: "square.grid.3x3.fill") }
                    ActivityView().tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }
                }
            } else {
                SetupView()
            }
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
            Text("Connect your spreadsheet").font(.title2.bold())
            Text("Choose your Excel file (for example camper_master.xlsx). BinFlow reads Sheet1 and writes every change straight back into the same file.\n\nA SKU with an empty Bin cell shows as Unavailable.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button { store.showPicker = true } label: {
                Label("Choose Excel file", systemImage: "folder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding(32)
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
