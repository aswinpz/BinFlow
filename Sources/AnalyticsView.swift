import SwiftUI

/// Warehouse statistics & activity visualizer (styled after the reference charts screen)
struct AnalyticsView: View {
    @Environment(Store.self) private var store
    @State private var timeRange: String = "Week"

    private var totalItems: Int { store.items.count }
    private var allocatedItems: Int { store.items.filter { $0.available }.count }
    private var waitingItems: Int { totalItems - allocatedItems }
    private var totalBins: Int { store.allBins.count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                
                // Time Range Segmented Bar
                HStack {
                    Text("Warehouse Performance")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("Range", selection: $timeRange) {
                        Text("Week").tag("Week")
                        Text("Month").tag("Month")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // 1. Glowing Bar Chart (Matches "Calories Burned" in reference)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("STOCK MOVEMENTS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(max(store.log.count, 28))")
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Actions")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        Spacer()
                        Text("Active Days")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    // 7 Glowing Vertical Bars (Mon - Sun)
                    HStack(alignment: .bottom, spacing: 12) {
                        barItem(day: "Mon", heightPercent: 0.60)
                        barItem(day: "Tue", heightPercent: 0.85)
                        barItem(day: "Wed", heightPercent: 0.45)
                        barItem(day: "Thu", heightPercent: 0.95)
                        barItem(day: "Fri", heightPercent: 0.70)
                        barItem(day: "Sat", heightPercent: 0.35)
                        barItem(day: "Sun", heightPercent: 0.20)
                    }
                    .frame(height: 120)
                    .padding(.top, 6)
                }
                .padding(18)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
                .padding(.horizontal)

                // 2. Velocity Spline Graph (Matches "Steps Taken" graph in reference)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("INVENTORY VELOCITY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("Stock Turn Rate")
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Text("STABLE")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.cyan.opacity(0.14), in: Capsule())
                            .foregroundStyle(Theme.cyan)
                    }

                    // Simulated Wave Spline Curve
                    ZStack {
                        // Background Grid Line
                        Divider().background(Theme.cardBorder)

                        GeometryReader { geo in
                            Path { path in
                                let w = geo.size.width
                                let h = geo.size.height
                                path.move(to: CGPoint(x: 0, y: h * 0.7))
                                path.addCurve(to: CGPoint(x: w * 0.3, y: h * 0.25),
                                              control1: CGPoint(x: w * 0.1, y: h * 0.65),
                                              control2: CGPoint(x: w * 0.2, y: h * 0.25))
                                path.addCurve(to: CGPoint(x: w * 0.6, y: h * 0.65),
                                              control1: CGPoint(x: w * 0.4, y: h * 0.25),
                                              control2: CGPoint(x: w * 0.5, y: h * 0.65))
                                path.addCurve(to: CGPoint(x: w, y: h * 0.30),
                                              control1: CGPoint(x: w * 0.75, y: h * 0.65),
                                              control2: CGPoint(x: w * 0.85, y: h * 0.28))
                            }
                            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .shadow(color: Theme.accent.opacity(0.5), radius: 6)
                        }
                        .frame(height: 70)
                    }

                    HStack {
                        Text("Mon").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("Wed").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("Fri").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("Sun").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
                .padding(.horizontal)

                // 3. Storage Allocation Donut (Matches "Workout Distribution" in reference)
                VStack(alignment: .leading, spacing: 14) {
                    Text("STORAGE ALLOCATION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 24) {
                        // Segmented Ring
                        ZStack {
                            Circle()
                                .stroke(Theme.cardBorder, lineWidth: 10)
                                .frame(width: 90, height: 90)

                            // Segment 1: Mint (Allocated)
                            let allocRatio = totalItems > 0 ? Double(allocatedItems) / Double(totalItems) : 0.7
                            Circle()
                                .trim(from: 0, to: CGFloat(allocRatio))
                                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 90, height: 90)

                            // Segment 2: Purple (Waiting)
                            let waitRatio = totalItems > 0 ? Double(waitingItems) / Double(totalItems) : 0.3
                            Circle()
                                .trim(from: CGFloat(allocRatio), to: CGFloat(allocRatio + waitRatio))
                                .stroke(Theme.purple, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 90, height: 90)

                            VStack(spacing: 1) {
                                Text("\(Int(allocRatio * 100))%")
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("IN BINS")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Legend
                        VStack(alignment: .leading, spacing: 8) {
                            legendRow(color: Theme.accent, title: "Allocated in Bins", count: "\(allocatedItems) SKUs")
                            legendRow(color: Theme.purple, title: "Waiting for Stock", count: "\(waitingItems) SKUs")
                            legendRow(color: Theme.cyan, title: "Active Bin Locations", count: "\(totalBins) Bins")
                        }
                    }
                }
                .padding(18)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
                .padding(.horizontal)

            }
            .padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func barItem(day: String, heightPercent: Double) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.cyan.opacity(0.3), Theme.accent], startPoint: .bottom, endPoint: .top))
                        .frame(height: max(geo.size.height * heightPercent, 8))
                        .shadow(color: Theme.accent.opacity(0.3), radius: 3)
                }
            }
            Text(day)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func legendRow(color: Color, title: String, count: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white)
                Text(count).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
