import SwiftUI
import Vision
import UIKit

/// Camper's public product image endpoint uses the product SKU as the image stem.
enum CamperCatalog {
    static func imageURL(for rawSKU: String) -> URL? {
        let sku = rawSKU.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            .replacingOccurrences(of: #"\s*[-–—−]\s*"#, with: "-", options: .regularExpression)
        guard sku.range(of: #"^[A-Z][A-Z0-9]{5,8}-[A-Z0-9]{3}$"#, options: .regularExpression) != nil else { return nil }
        return URL(string: "https://cloud.camper.com/is/image/JGVzaG9wMDNtYmlnZ3JleSQ=/\(sku)_DF.jpg")
    }
}

struct CamperProductImage: View {
    let sku: String
    var size: CGFloat = 112

    var body: some View {
        Group {
            if let url = CamperCatalog.imageURL(for: sku) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(Theme.cardSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
        .accessibilityLabel("Camper catalog image for \(sku), when available")
    }

    private var placeholder: some View {
        Image(systemName: "shoe")
            .resizable().scaledToFit().padding(size * 0.28)
            .foregroundStyle(Theme.accent.opacity(0.65))
    }
}

struct VisualMatch: Identifiable {
    let item: ItemInfo
    let distance: Float
    var id: String { item.sku }
}

/// Compares a camera photo with official Camper product thumbnails using Vision feature prints.
/// Network work is bounded and independent of spreadsheet lookup; no result is possible offline.
enum CamperVisualMatcher {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 6
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration)
    }()

    static func matches(photo: UIImage, items: [ItemInfo], limit: Int = 96) async -> [VisualMatch] {
        guard let query = featurePrint(for: photo) else { return [] }
        let candidates = Array(items.prefix(limit))
        return await withTaskGroup(of: VisualMatch?.self, returning: [VisualMatch].self) { group in
            var next = candidates.makeIterator()
            for _ in 0..<min(6, candidates.count) {
                if let item = next.next() {
                    group.addTask { await compare(query: query, item: item) }
                }
            }
            var results: [VisualMatch] = []
            while let result = await group.next() {
                if let result { results.append(result) }
                if let item = next.next() {
                    group.addTask { await compare(query: query, item: item) }
                }
            }
            return Array(results.sorted { $0.distance < $1.distance }.prefix(3))
        }
    }

    private static func compare(query: VNFeaturePrintObservation, item: ItemInfo) async -> VisualMatch? {
        guard let url = CamperCatalog.imageURL(for: item.sku),
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let reference = featurePrint(for: data) else { return nil }
        var distance: Float = 0
        guard (try? query.computeDistance(&distance, to: reference)) != nil,
              distance.isFinite else { return nil }
        return VisualMatch(item: item, distance: distance)
    }

    private static func featurePrint(for image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFit
        guard (try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])) != nil else { return nil }
        return request.results?.first as? VNFeaturePrintObservation
    }

    private static func featurePrint(for data: Data) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFit
        guard (try? VNImageRequestHandler(data: data, options: [:]).perform([request])) != nil else { return nil }
        return request.results?.first as? VNFeaturePrintObservation
    }
}
