import SwiftUI
import SwiftData

struct ActivityView: View {
    @Query(sort: \Movement.date, order: .reverse) private var moves: [Movement]

    var body: some View {
        NavigationStack {
            List(moves) { m in
                HStack(spacing: 12) {
                    Image(systemName: m.kind == "In" ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2).foregroundStyle(m.kind == "In" ? Theme.accent : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(m.qty) × \(m.name)").font(.headline)
                        Text("\(m.kind == "In" ? "to" : "from") \(m.binCode) · \(m.date, format: .relative(presentation: .named))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .overlay { if moves.isEmpty { ContentUnavailableView("No activity", systemImage: "clock") } }
            .navigationTitle("Activity")
        }
    }
}
