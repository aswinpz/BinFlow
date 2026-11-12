import SwiftUI
import VisionKit
import Vision
import ImageIO

/// Finds SKUs in text read by the camera.
/// Label format: one letter, six digits, a dash, three digits (e.g. K300530 - 007).
enum SKUMatch {
    /// Uppercase, keep letters/digits only, and treat look-alikes (O/0, I/L/1) as the same.
    static func normalize(_ s: String) -> String {
        String(s.uppercased().filter { $0.isLetter || $0.isNumber }.map { c -> Character in
            switch c { case "O": return "0"; case "I", "L": return "1"; default: return c }
        })
    }

    static func map(_ items: [ItemInfo]) -> [String: String] {
        Dictionary(items.map { (normalize($0.sku), $0.sku) }, uniquingKeysWith: { a, _ in a })
    }

    private static let codeRegex = try? NSRegularExpression(
        pattern: #"(?<![A-Z0-9])([A-Z]{1,2})([0-9OIL]{5,7})(?:\s*[-–—−]\s*([0-9OIL]{2,3}))?(?![A-Z0-9])"#)

    private static func fixDigits(_ s: String) -> String {
        String(s.map { c -> Character in
            switch c { case "O": return "0"; case "I", "L": return "1"; default: return c }
        })
    }

    /// A SKU-shaped code in the text, whether or not it is in the sheet, e.g. "K300530-007".
    static func code(in raw: String) -> String? {
        guard let re = codeRegex else { return nil }
        let up = raw.uppercased()
        let ns = up as NSString
        for m in re.matches(in: up, range: NSRange(location: 0, length: ns.length)) {
            let prefix = ns.substring(with: m.range(at: 1))
            let style = ns.substring(with: m.range(at: 2))
            guard style.filter({ $0.isNumber }).count >= 4 else { continue }
            var out = prefix + fixDigits(style)
            if m.range(at: 3).location != NSNotFound {
                out += "-" + fixDigits(ns.substring(with: m.range(at: 3)))
            }
            return out
        }
        return nil
    }

    /// Returns the sheet SKU if `raw` is (or contains) one; otherwise any SKU-shaped code it holds.
    static func find(in raw: String, _ known: [String: String]) -> String? {
        let whole = normalize(raw)
        if let s = known[whole] { return s }
        for tok in raw.components(separatedBy: .whitespacesAndNewlines) {
            if let s = known[normalize(tok)] { return s }
        }
        for (k, v) in known where k.count >= 6 && whole.contains(k) { return v }
        if let c = code(in: raw) { return known[normalize(c)] ?? family(in: c, known) ?? c }
        return family(in: raw, known)
    }

    /// If sheet SKUs start with this code (one per size), return the single SKU,
    /// or the shared prefix so Search lists every size.
    private static func family(in raw: String, _ known: [String: String]) -> String? {
        for tok in raw.components(separatedBy: .whitespacesAndNewlines) {
            let n = normalize(tok)
            guard n.count >= 6, n.contains(where: { $0.isNumber }) else { continue }
            let skus = known.filter { $0.key.hasPrefix(n) }.map { $0.value }
            if skus.count == 1 { return skus[0] }
            if skus.count > 1, let p = commonPrefix(skus), p.count >= 4 { return p }
        }
        return nil
    }

    private static func commonPrefix(_ items: [String]) -> String? {
        guard var p = items.first else { return nil }
        for s in items.dropFirst() {
            while !s.hasPrefix(p) { p = String(p.dropLast()); if p.isEmpty { return nil } }
        }
        return p
    }

    /// Slow, full-resolution read of a still photo. Catches small print the live view misses.
    static func recognize(in image: UIImage, known: [String: String]) -> String? {
        guard let cg = image.cgImage else { return nil }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        req.minimumTextHeight = 0.004
        let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation(image.imageOrientation), options: [:])
        try? handler.perform([req])
        for obs in req.results ?? [] {
            for cand in obs.topCandidates(3) {
                if let s = find(in: cand.string, known) { return s }
            }
        }
        return nil
    }

    private static func orientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

final class ScannerHandle { weak var vc: DataScannerViewController? }

struct ScanSheet: View {
    var onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(Store.self) private var store
    @State private var zoom = 1.0
    @State private var handle = ScannerHandle()
    @State private var reading = false
    @State private var matching = false
    @State private var visualMatches: [VisualMatch] = []
    @State private var hint = "Point at the SKU, e.g. K300530-007"

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    ScannerRepresentable(known: SKUMatch.map(store.items), zoom: zoom, handle: handle) {
                        onScan($0); dismiss()
                    }
                    .ignoresSafeArea()
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 12) {
                            if !visualMatches.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Approximate visual matches — choose the correct shoe")
                                        .font(.caption.weight(.bold)).foregroundStyle(.primary)
                                    ForEach(visualMatches) { match in
                                        Button {
                                            onScan(match.item.sku)
                                            dismiss()
                                        } label: {
                                            HStack(spacing: 10) {
                                                CamperProductImage(sku: match.item.sku, size: 58)
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(match.item.name.isEmpty ? match.item.sku : match.item.name)
                                                        .font(.subheadline.weight(.bold)).lineLimit(1)
                                                    Text(match.item.sku).font(.caption.monospaced()).foregroundStyle(.secondary)
                                                    Text(match.item.bins.isEmpty ? "No bin assigned" : "Bin: \(match.item.bins.joined(separator: ", "))")
                                                        .font(.caption2).foregroundStyle(match.item.available ? Theme.accent : Theme.warn)
                                                        .lineLimit(1)
                                                }
                                                Spacer(minLength: 0)
                                                Image(systemName: "chevron.right").font(.caption.bold())
                                            }
                                            .padding(8)
                                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.primary)
                                    }
                                    Text("Only a sample of catalog products is checked. Compare the photo carefully; use OCR or search if it isn't listed.")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .padding(.horizontal, 12)
                            }

                            VStack(spacing: 9) {
                                HStack(spacing: 8) {
                                    ForEach([1.0, 2.0, 3.0, 4.0], id: \.self) { z in
                                        Button { zoom = z } label: {
                                            Text("\(Int(z))x").font(.footnote.weight(.bold).monospacedDigit())
                                                .frame(width: 44, height: 34)
                                                .background(zoom == z ? Theme.accent : Color.black.opacity(0.55), in: Capsule())
                                                .foregroundStyle(zoom == z ? Color.black : Color.white)
                                        }
                                    }
                                }
                                HStack(spacing: 10) {
                                    Button { readPhoto() } label: {
                                        Label(reading ? "Reading…" : "Read SKU", systemImage: "camera.aperture")
                                            .font(.footnote.weight(.bold)).frame(maxWidth: .infinity).frame(height: 42)
                                            .background(Theme.pink, in: Capsule()).foregroundStyle(.white)
                                    }.disabled(reading || matching)
                                    Button { identifyShoe() } label: {
                                        Label(matching ? "Matching…" : "Identify shoe", systemImage: "photo.magnifyingglass")
                                            .font(.footnote.weight(.bold)).frame(maxWidth: .infinity).frame(height: 42)
                                            .background(Theme.accent, in: Capsule()).foregroundStyle(.black)
                                    }.disabled(reading || matching)
                                }
                            }
                            Label(hint, systemImage: "text.viewfinder")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.6), lineWidth: 1))
                        }
                        .padding(.bottom, 40)
                    }
                } else {
                    ContentUnavailableView("Scanner unavailable", systemImage: "camera.slash",
                        description: Text("Allow camera access in Settings, or type the code instead."))
                }
            }
            .navigationTitle("Scan SKU").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    /// Takes a full-resolution photo and reads it carefully. For small or hard-to-read text.
    private func readPhoto() {
        guard let vc = handle.vc, !reading else { return }
        reading = true
        let known = SKUMatch.map(store.items)
        Task {
            defer { reading = false }
            do {
                let img = try await vc.capturePhoto()
                let found = await Task.detached(priority: .userInitiated) {
                    SKUMatch.recognize(in: img, known: known)
                }.value
                if let found { onScan(found); dismiss() }
                else { hint = "No SKU found. Move closer and try again" }
            } catch {
                hint = "Couldn't take the photo. Try again"
            }
        }
    }

    /// Captures the current camera view and compares it with official Camper catalog thumbnails.
    private func identifyShoe() {
        guard let vc = handle.vc, !matching else { return }
        matching = true
        visualMatches = []
        hint = "Comparing with Camper catalog images…"
        let catalog = store.items
        Task {
            defer { matching = false }
            do {
                let image = try await vc.capturePhoto()
                let found = await Task.detached(priority: .userInitiated) {
                    await CamperVisualMatcher.matches(photo: image, items: catalog, limit: 48)
                }.value
                visualMatches = found
                hint = found.isEmpty
                    ? "No catalog image match. Use OCR or search instead."
                    : "Review the closest matches below and choose the right item."
            } catch {
                hint = "Couldn't capture the shoe photo. Try again or use OCR."
            }
        }
    }
}

struct ScannerRepresentable: UIViewControllerRepresentable {
    let known: [String: String]
    var zoom: Double = 1.0
    var handle: ScannerHandle? = nil
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .accurate,
                                           recognizesMultipleItems: true, isHighFrameRateTrackingEnabled: false,
                                           isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        handle?.vc = vc
        DispatchQueue.main.async { try? vc.startScanning() }
        return vc
    }
    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        let z = min(max(zoom, vc.minZoomFactor), vc.maxZoomFactor)
        if abs(vc.zoomFactor - z) > 0.01 { vc.zoomFactor = z }
    }
    func makeCoordinator() -> Coordinator { Coordinator(known: known, onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let known: [String: String]
        let onScan: (String) -> Void
        private var done = false
        private var hits: [String: Int] = [:]

        init(known: [String: String], onScan: @escaping (String) -> Void) {
            self.known = known; self.onScan = onScan
        }

        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) { handle(items) }
        func dataScanner(_ s: DataScannerViewController, didUpdate items: [RecognizedItem], allItems: [RecognizedItem]) { handle(items) }
        func dataScanner(_ s: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let t) = item {
                finish(SKUMatch.find(in: t.transcript, known) ?? t.transcript.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        private func handle(_ items: [RecognizedItem]) {
            for item in items {
                if case .text(let t) = item, let sku = SKUMatch.find(in: t.transcript, known) {
                    // Seen in two consecutive frames, to avoid misreads.
                    hits[sku, default: 0] += 1
                    if hits[sku, default: 0] >= 2 { finish(sku); return }
                }
            }
        }

        private func finish(_ value: String?) {
            guard !done, let value, !value.isEmpty else { return }
            done = true
            if UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            onScan(value)
        }
    }
}
