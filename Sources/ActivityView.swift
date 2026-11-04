import SwiftUI
import SwiftData

struct ActivityView: View {
    @Query(sort: \Movement.date, order: .reverse) private var moves: [Movement]
    private var incoming: Int { moves.filter { $0.kind == "In" }.reduce(0) { $0 + $1.qty } }
    private var outgoing: Int { moves.filter { $0.kind == "Out" }.reduce(0) { $0 + $1.qty } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(eyebrow: "Warehouse log", title: "Activity", subtitle: "A timeline of stock coming in and going out.")
                    HStack(spacing: 10) {
                        MetricTile(title: "Received", value: "\(incoming)", symbol: "arrow.down.left")
                        MetricTile(title: "Picked", value: "\(outgoing)", symbol: "arrow.up.right")
                    }
                    SectionLabel(title: "Recent movements", trailing: "\(moves.count) records")
                    if moves.isEmpty {
                        ContentUnavailableView("No activity yet", systemImage: "clock.arrow.circlepath",
                            description: Text("Incoming allocations and picked stock will appear here."))
                            .frame(maxWidth: .infinity).padding(.vertical, 30)
                    } else {
                        SurfaceCard {
                            ForEach(Array(moves.enumerated()), id: \.element.persistentModelID) { index, move in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: move.kind == "In" ? "arrow.down.left" : "arrow.up.right")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(move.kind == "In" ? Theme.accent : .orange)
                                        .frame(width: 38, height: 38)
                                        .background((move.kind == "In" ? Theme.accent : Color.orange).opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(move.qty) × \(move.name)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                        Text("\(move.kind == "In" ? "To" : "From") \(move.binCode) · \(move.sku)")
                                            .font(.caption).foregroundStyle(Theme.muted)
                                        Text(move.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.caption2).foregroundStyle(.tertiary)
                                    }
                                    Spacer(minLength: 4)
                                    Text(move.kind == "In" ? "+\(move.qty)" : "−\(move.qty)")
                                        .font(.subheadline.monospacedDigit().weight(.bold))
                                        .foregroundStyle(move.kind == "In" ? Theme.accent : .orange)
                                }
                                .padding(.vertical, 5)
                                if index < moves.count - 1 { Divider().overlay(Theme.line) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 28)
            }
            .background(Theme.canvas).toolbar(.hidden, for: .navigationBar)
        }
    }
}
