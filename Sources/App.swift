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
    static let accent = Color(red: 0.10, green: 0.38, blue: 0.32)
    static let ink = Color(red: 0.12, green: 0.16, blue: 0.15)
    static let muted = Color(red: 0.43, green: 0.48, blue: 0.46)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let line = Color(uiColor: .separator).opacity(0.18)
    static func fill(_ f: Double) -> Color { f < 0.7 ? .green : (f < 0.9 ? .orange : .red) }
}

struct RootView: View {
    var body: some View {
        TabView {
            FindView()
                .tabItem { Label("Find", systemImage: "magnifyingglass") }
            AllocateView()
                .tabItem { Label("Allocate", systemImage: "shippingbox") }
            BinsView()
                .tabItem { Label("Bins", systemImage: "square.grid.2x2") }
            ActivityView()
                .tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }
        }
        .tint(Theme.accent)
    }
}

struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String
    var body: some View {
        SurfaceCard {
            Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(Theme.accent)
            Text(value).font(.system(size: 25, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(Theme.muted)
        }
    }
}

struct SectionLabel: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(title).font(.headline.weight(.bold)).foregroundStyle(Theme.ink)
            Spacer()
            if let trailing { Text(trailing).font(.caption.weight(.medium)).foregroundStyle(Theme.muted) }
        }
        .padding(.top, 4)
    }
}
