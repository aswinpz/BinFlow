import SwiftUI
import PhotosUI
import UIKit

private struct PaletteChoice: Identifiable {
    let name: String
    let color: Color
    var id: String { name }

    static let all: [PaletteChoice] = [
        .init(name: "Mint", color: Color(red: 0.00, green: 0.82, blue: 0.56)),
        .init(name: "Ocean", color: Color(red: 0.12, green: 0.48, blue: 0.98)),
        .init(name: "Sunset", color: Color(red: 0.98, green: 0.30, blue: 0.20)),
        .init(name: "Berry", color: Color(red: 0.91, green: 0.20, blue: 0.56)),
        .init(name: "Orchid", color: Color(red: 0.60, green: 0.31, blue: 0.94)),
        .init(name: "Forest", color: Color(red: 0.08, green: 0.62, blue: 0.36)),
        .init(name: "Amber", color: Color(red: 0.92, green: 0.55, blue: 0.05)),
        .init(name: "Rose", color: Color(red: 0.88, green: 0.30, blue: 0.42))
    ]
}

struct SettingsView: View {
    @Environment(Store.self) private var store
    @AppStorage("userName") private var userName = "Aswin"
    @AppStorage("profilePhotoData") private var profilePhotoData = Data()
    @AppStorage("autoReload") private var autoReload = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("colorTheme") private var colorTheme = "Mint"
    @AppStorage("colorMode") private var colorMode = "dark"
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var confirmDisconnect = false
    @State private var confirmClearLog = false

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $colorMode) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    ForEach(PaletteChoice.all) { choice in
                        Button { colorTheme = choice.name } label: {
                            HStack(spacing: 9) {
                                Circle().fill(choice.color).frame(width: 16, height: 16)
                                Text(choice.name).font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                                if colorTheme == choice.name {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(choice.color)
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 11)
                            .background(colorTheme == choice.name ? choice.color.opacity(0.12) : Theme.cardSubtle,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(colorTheme == choice.name ? choice.color.opacity(0.45) : Theme.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.primaryText)
                    }
                }
                .padding(.vertical, 4)
            } header: { Text("Appearance") } footer: {
                Text("Choose an accent palette and switch between light and dark appearance.")
            }

            Section {
                LabeledContent("File", value: store.fileName.isEmpty ? "None" : store.fileName)
                LabeledContent("Contents", value: "\(store.items.count) SKUs · \(store.allBins.count) bins")
                Button("Reload from file", systemImage: "arrow.clockwise") { store.reload() }
                Button("Choose a different Excel file", systemImage: "folder") { store.showPicker = true }
                if let url = store.fileURL { ShareLink("Share / back up a copy", item: url) }
                Toggle("Reload when app opens", isOn: $autoReload)
                Button("Disconnect file", systemImage: "link.badge.minus", role: .destructive) { confirmDisconnect = true }
            } header: { Text("Excel file") } footer: {
                Text("CAMPX DXB reads Sheet1 and saves every change straight into this file. If Excel or another app edits it, reload to pick up the changes.")
            }

            Section {
                Toggle("Haptic feedback", isOn: $haptics)
            } header: { Text("Scanner") } footer: {
                Text("Scan printed SKU labels with OCR, or use the separate photo-match option to compare a shoe with available Camper catalog thumbnails. Photo matching needs internet; normal spreadsheet search does not.")
            }

            Section("Profile") {
                HStack(spacing: 14) {
                    profilePreview
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Profile picture").font(.subheadline.weight(.semibold))
                        Text(profilePhotoData.isEmpty ? "Shown in the top-right avatar" : "Picture saved on this device")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose profile picture", systemImage: "person.crop.circle.badge.plus")
                }
                if !profilePhotoData.isEmpty {
                    Button("Remove profile picture", systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                        profilePhotoData = Data()
                    }
                }
                TextField("Your name", text: $userName)
            }

            Section("Data") {
                Button("Clear activity log", systemImage: "trash", role: .destructive) { confirmClearLog = true }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("Settings")
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let resized = resizedJPEG(image) else { return }
                profilePhotoData = resized
            }
        }
        .confirmationDialog("Disconnect the spreadsheet?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) { store.disconnect() }
        } message: { Text("The file stays where it is. You'll be asked to choose a file again.") }
        .confirmationDialog("Clear the activity log?", isPresented: $confirmClearLog, titleVisibility: .visible) {
            Button("Clear log", role: .destructive) { store.clearLog() }
        }
    }

    @ViewBuilder
    private var profilePreview: some View {
        if let image = UIImage(data: profilePhotoData), !profilePhotoData.isEmpty {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: 54, height: 54).clipShape(Circle())
                .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 48)).foregroundStyle(Theme.accent)
        }
    }

    private func resizedJPEG(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 360
        let ratio = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let scaled = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return scaled.jpegData(compressionQuality: 0.82)
    }
}
