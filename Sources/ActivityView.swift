import SwiftUI

struct ActivityView: View {
    @Environment(Store.self) private var store

    private func icon(_ k: String) -> (String, Color) {
        switch k {
        case "In": return ("arrow.down.circle.fill", Theme.accent)
        case "Out": return ("arrow.up.circle.fill", .orange)
        case "New": return ("plus.circle.fill", .blue)
        case "Delete": return ("trash.circle.fill", .red)
        default: return ("pencil.circle.fill", .gray)
        }
    }
    private func title(_ m: LogEntry) -> String {
        let who = m.name.isEmpty ? m.sku : m.name
        switch m.kind {
        case "In": return "\(who) → \(m.bin)"
        case "Out": return "\(who) removed from \(m.bin)"
        case "New": return "Added \(who)" + (m.bin.isEmpty ? " (unavailable)" : " in \(m.bin)")
        case "Delete": return "Deleted \(who)"
        default: return "Edited \(who)"
        }
    }

    var body: some View {
        Group {
            List(store.log) { m in
                HStack(spacing: 12) {
                    Image(systemName: icon(m.kind).0).font(.title3).foregroundStyle(icon(m.kind).1)
                        .frame(width: 40, height: 40)
                        .background(icon(m.kind).1.opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(m)).font(.headline).lineLimit(2)
                        Text("\(m.sku) · \(m.date, format: .relative(presentation: .named))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.cardRow()
            }
            .cardList()
            .overlay { if store.log.isEmpty { ContentUnavailableView("No activity yet", systemImage: "clock", description: Text("Changes you make in the app show up here.")) } }
            .navigationTitle("Activity")
        }
    }
}
