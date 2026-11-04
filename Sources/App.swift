import SwiftUI
import SwiftData

@main
struct BinFlowApp: App {
    var body: some Scene {
        WindowGroup { RootView().tint(Theme.accent) }
            .modelContainer(for: [Bin.self, Item.self, StockLine.self, Movement.self])
    }
}

enum Theme {
    static let accent = Color(red: 0.0, green: 0.46, blue: 0.43)
    static func fill(_ f: Double) -> Color { f < 0.7 ? .green : (f < 0.9 ? .orange : .red) }
}

struct RootView: View {
    var body: some View {
        TabView {
            FindView().tabItem { Label("Find", systemImage: "magnifyingglass") }
            AllocateView().tabItem { Label("Allocate", systemImage: "shippingbox.and.arrow.backward") }
            BinsView().tabItem { Label("Bins", systemImage: "square.grid.3x3.fill") }
            ActivityView().tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }
        }
    }
}
