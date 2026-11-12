import SwiftUI

enum Route: Hashable { case find(String), receive, bins, activity, settings, edit, analytics }

struct HomeView: View {
    @Environment(Store.self) private var store
    @AppStorage("userName") private var userName = "Aswin"
    @State private var path = NavigationPath()
    @State private var scanning = false
    @State private var adding = false
    @State private var confirmExit = false
    @State private var pulse = false

    private var totalItems: Int { store.items.count }
    private var allocatedItems: Int { store.items.filter { $0.available }.count }
    private var waitingItems: Int { totalItems - allocatedItems }
    private var allocPercent: Double {
        totalItems > 0 ? Double(allocatedItems) / Double(totalItems) : 0
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        // Header (Matches "GYMFIT" / Welcome back, Jason)
                        headerView

                        // Hero Radial Progress Card (Matches "Today's Progress 75%")
                        heroProgressCard

                        // 2x2 Metric Matrix (Matches 72 BPM / 5 days / 7h 32m / 185 lbs)
                        metricMatrixView

                        // Quick Search Bar
                        searchBarPreview

                        // Menu Section
                        VStack(spacing: 12) {
                            NavigationLink(value: Route.find("")) {
                                MenuCard(icon: "magnifyingglass", color: Theme.accent, title: "Search SKU", subtitle: "Find products and bin locations")
                            }
                            Button { adding = true } label: {
                                MenuCard(icon: "cart.badge.plus", color: Theme.green, title: "Add SKU", subtitle: "Register a new product to sheet")
                            }
                            NavigationLink(value: Route.receive) {
                                MenuCard(icon: "shippingbox.and.arrow.backward", color: Theme.warn, title: "Receive Stock", subtitle: "Assign bins to waiting inventory")
                            }
                            NavigationLink(value: Route.bins) {
                                MenuCard(icon: "square.grid.3x3.fill", color: Theme.blue, title: "Bin Explorer", subtitle: "Browse bins by warehouse zone")
                            }
                            NavigationLink(value: Route.analytics) {
                                MenuCard(icon: "chart.bar.xaxis", color: Theme.purple, title: "Warehouse Analytics", subtitle: "Velocity, trends & distribution")
                            }
                            NavigationLink(value: Route.edit) {
                                MenuCard(icon: "square.and.pencil", color: Theme.blue, title: "Edit SKU", subtitle: "Update product information")
                            }
                            NavigationLink(value: Route.activity) {
                                MenuCard(icon: "clock.arrow.circlepath", color: Theme.accent, title: "Activity Log", subtitle: "Track changes and audit trail")
                            }
                            NavigationLink(value: Route.settings) {
                                MenuCard(icon: "gearshape.fill", color: .gray, title: "Settings", subtitle: "File connection & preferences")
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        footer
                    }
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .find(let q): FindView(initialText: q)
                case .receive: ReceiveView()
                case .bins: BinsView()
                case .activity: ActivityView()
                case .settings: SettingsView()
                case .edit: EditSKUView()
                case .analytics: AnalyticsView()
                }
            }
            .binflowDestinations()
            .sheet(isPresented: $scanning) { ScanSheet { handle($0) } }
            .sheet(isPresented: $adding) { EditItemSheet(sku: nil) }
            .confirmationDialog("Close BinFlow?", isPresented: $confirmExit, titleVisibility: .visible) {
                Button("Close app", role: .destructive) { exit(0) }
            } message: { Text("Your spreadsheet is already saved after every change.") }
        }
    }

    private func handle(_ code: String) {
        if store.item(code) != nil { path.append(code) } else { path.append(Route.find(code)) }
    }

    // Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("BINFLOW PRO")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.accent)
                    .tracking(2)
                Text("Welcome back,\n\(userName)")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(.white)
            }
            Spacer()

            HStack(spacing: 12) {
                // Quick Camera Barcode Scanner Button
                Button { scanning = true } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Theme.card)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 1))
                }

                // Operator Avatar Badge with Glowing Online Dot
                NavigationLink(value: Route.settings) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(Theme.card)
                            .frame(width: 42, height: 42)
                            .overlay(
                                Text(String(userName.prefix(2)).uppercased())
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(Theme.accent)
                            )
                            .overlay(Circle().stroke(Theme.accent.opacity(0.8), lineWidth: 1.5))

                        Circle()
                            .fill(Theme.green)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Theme.bg, lineWidth: 2))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // Hero Radial Progress Card (75% Circular Ring from Reference)
    private var heroProgressCard: some View {
        HStack(spacing: 18) {
            RadialProgressGauge(percent: allocPercent, title: "ALLOCATED", lineWidth: 9)
                .frame(width: 90, height: 90)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle().fill(Theme.warn).frame(width: 6, height: 6)
                        Text("Allocated SKUs:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(allocatedItems) / \(totalItems)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    ProgressView(value: Double(allocatedItems), total: Double(max(totalItems, 1)))
                        .tint(Theme.warn)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle().fill(Theme.accent).frame(width: 6, height: 6)
                        Text("Active Bins:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(store.allBins.count) Bins")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    ProgressView(value: Double(store.allBins.count), total: Double(max(store.allBins.count + 5, 20)))
                        .tint(Theme.accent)
                }
            }
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // 2x2 Metric Matrix (Matches 4 Stat Cards in Reference)
    private var metricMatrixView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCard(title: "TOTAL SKUS", value: "\(totalItems)", badge: "▲ Catalog", badgeColor: Theme.accent, icon: "shippingbox.fill", iconColor: Theme.accent)
            metricCard(title: "BINS ACTIVE", value: "\(store.allBins.count)", badge: "✓ Zones", badgeColor: Theme.accent, icon: "square.grid.3x3.fill", iconColor: Theme.blue)
            metricCard(title: "ALLOCATION", value: "\(Int(allocPercent * 100))%", badge: "✓ In Stock", badgeColor: Theme.green, icon: "checkmark.shield.fill", iconColor: Theme.green)
            metricCard(title: "WAITING STOCK", value: "\(waitingItems)", badge: waitingItems > 0 ? "⚠️ Need Bin" : "✓ None", badgeColor: waitingItems > 0 ? Theme.warn : Theme.accent, icon: "exclamationmark.triangle.fill", iconColor: Theme.warn)
        }
        .padding(.horizontal, 20)
    }

    private func metricCard(title: String, value: String, badge: String, badgeColor: Color, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(iconColor)
            }
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(badge)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(badgeColor)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
    }

    // Quick Search Preview Capsule
    private var searchBarPreview: some View {
        NavigationLink(value: Route.find("")) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("Search SKU, name or bin code...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
            Text("BINFLOW").font(.footnote.weight(.black)).tracking(5).foregroundStyle(.secondary)
            Image(systemName: "shippingbox").font(.footnote).foregroundStyle(Theme.accent)
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
}

struct MenuCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.25), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline.weight(.bold)).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Pick a SKU, then edit its details.
struct EditSKUView: View {
    @Environment(Store.self) private var store
    @State private var text = ""
    @State private var target: MoveTarget?

    private var results: [ItemInfo] {
        let q = text.trimmed
        guard !q.isEmpty else { return store.items }
        return store.items.filter {
            $0.sku.localizedCaseInsensitiveContains(q) || $0.name.localizedCaseInsensitiveContains(q)
                || $0.family.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        List {
            ForEach(results) { it in
                Button { target = MoveTarget(id: it.sku) } label: { ItemRow(item: it) }
                    .foregroundStyle(.primary).cardRow()
            }
        }
        .cardList()
        .overlay { if results.isEmpty && !text.isEmpty { ContentUnavailableView.search(text: text) } }
        .navigationTitle("Edit SKU")
        .searchable(text: $text, prompt: "Find the SKU to edit")
        .sheet(item: $target) { EditItemSheet(sku: $0.id) }
    }
}
