import SwiftUI
import WidgetKit

private enum CAMPXWidgetLinks {
    static let scan = URL(string: "campxdxb://scan")!
    static let find = URL(string: "campxdxb://find")!
    static let add = URL(string: "campxdxb://add")!
}

private struct QuickActionsEntry: TimelineEntry {
    let date: Date
}

private struct QuickActionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry {
        QuickActionsEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(QuickActionsEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        completion(Timeline(entries: [QuickActionsEntry(date: Date())], policy: .never))
    }
}

private struct QuickActionsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemMedium {
                mediumLayout
            } else {
                smallLayout
            }
        }
        .containerBackground(Color(.systemBackground), for: .widget)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox.fill").foregroundStyle(Color.accentColor)
                Text("CAMPX DXB").font(.caption.weight(.heavy))
            }
            actionRow("Scan SKU", icon: "viewfinder", url: CAMPXWidgetLinks.scan)
            actionRow("Find SKU", icon: "magnifyingglass", url: CAMPXWidgetLinks.find)
            actionRow("Add SKU", icon: "plus.circle.fill", url: CAMPXWidgetLinks.add)
            Spacer(minLength: 0)
        }
        .padding(13)
    }

    private var mediumLayout: some View {
        HStack(spacing: 10) {
            mediumAction("Scan SKU", subtitle: "Read a label", icon: "viewfinder", url: CAMPXWidgetLinks.scan)
            mediumAction("Find SKU", subtitle: "Search bins", icon: "magnifyingglass", url: CAMPXWidgetLinks.find)
            mediumAction("Add SKU", subtitle: "New product", icon: "plus.circle.fill", url: CAMPXWidgetLinks.add)
        }
        .padding(12)
    }

    private func actionRow(_ title: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                Text(title).font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
        .accessibilityLabel(title)
    }

    private func mediumAction(_ title: String, subtitle: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.caption.weight(.bold)).lineLimit(1)
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
            .contentShape(RoundedRectangle(cornerRadius: 15))
        }
        .foregroundStyle(.primary)
        .accessibilityLabel("\(title), \(subtitle)")
    }
}

struct CAMPXQuickActionsWidget: Widget {
    private let kind = "CAMPXQuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsProvider()) { _ in
            QuickActionsWidgetView()
        }
        .configurationDisplayName("CAMPX DXB Quick Actions")
        .description("Quickly scan, find, or add a SKU.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CAMPXWidgetBundle: WidgetBundle {
    var body: some Widget {
        CAMPXQuickActionsWidget()
    }
}
