import SwiftUI

enum Route: Hashable { case find(String), receive, bins, activity, settings, edit }

struct HomeView: View {
    @Environment(Store.self) private var store
    @AppStorage("userName") private var userName = "Aswin"
    @State private var path = NavigationPath()
    @State private var scanning = false
    @State private var adding = false
    @State private var confirmExit = false
    @State private var pulse = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                background
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        hero
                        VStack(spacing: 12) {
                            NavigationLink(value: Route.find("")) {
                                MenuCard(icon: "magnifyingglass", color: Theme.accent, title: "Search SKU", subtitle: "Find products and bin locations")
                            }
                            Button { adding = true } label: {
                                MenuCard(icon: "cart.badge.plus", color: Theme.green, title: "Add SKU", subtitle: "Register a new product")
                            }
                            NavigationLink(value: Route.edit) {
                                MenuCard(icon: "square.and.pencil", color: Theme.blue, title: "Edit SKU", subtitle: "Update product information")
                            }
                            NavigationLink(value: Route.settings) {
                                MenuCard(icon: "gearshape", color: Theme.blue, title: "Settings", subtitle: "Manage your application")
                            }
                            Button { confirmExit = true } label: {
                                MenuCard(icon: "rectangle.portrait.and.arrow.right", color: Theme.blue, title: "Exit", subtitle: "Close the application")
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)

                        quickLinks
                        footer
                    }
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

    private var background: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.pink.opacity(0.18), .clear], center: .init(x: 0.5, y: 0.28), startRadius: 10, endRadius: 280)
            RadialGradient(colors: [Theme.accent.opacity(0.10), .clear], center: .init(x: 0.1, y: 0.0), startRadius: 10, endRadius: 320)
        }.ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hi \(userName)").font(.system(size: 42, weight: .heavy)).foregroundStyle(.white)
            Text("WELCOME BACK").font(.subheadline.weight(.medium)).tracking(7).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24).padding(.top, 36)
    }

    private var hero: some View {
        Button { scanning = true } label: {
            VStack(spacing: 10) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 104, weight: .ultraLight))
                    .foregroundStyle(Theme.pink)
                    .shadow(color: Theme.pink.opacity(0.9), radius: 6)
                    .shadow(color: Theme.pink.opacity(0.6), radius: 18)
                    .scaleEffect(pulse ? 1.04 : 0.96)
                Text("TAP TO SCAN SKU").font(.caption.weight(.semibold)).tracking(5).foregroundStyle(Theme.pink.opacity(0.85))
            }
            .frame(maxWidth: .infinity).frame(height: 230)
        }
        .buttonStyle(.plain)
        .onAppear { withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { pulse = true } }
    }

    private var quickLinks: some View {
        HStack(spacing: 10) {
            quick("Receive", "shippingbox.and.arrow.backward", .receive)
            quick("Bins", "square.grid.3x3.fill", .bins)
            quick("Activity", "clock.arrow.circlepath", .activity)
        }
        .padding(.horizontal, 20).padding(.top, 18)
    }

    private func quick(_ title: String, _ icon: String, _ route: Route) -> some View {
        NavigationLink(value: route) {
            Label(title, systemImage: icon).font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(Color.white.opacity(0.06), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1))
                .foregroundStyle(Theme.accent)
        }.buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            Text("THAPPUMON").font(.footnote.weight(.medium)).tracking(7).foregroundStyle(.secondary)
            Image(systemName: "magnifyingglass").font(.footnote).foregroundStyle(.secondary)
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
        }
        .padding(.horizontal, 20).padding(.vertical, 26)
    }
}

struct MenuCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
                .shadow(color: color.opacity(0.9), radius: 6)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color(white: 0.14), Color(white: 0.06)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
