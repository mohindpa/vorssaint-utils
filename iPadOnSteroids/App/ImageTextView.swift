// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import PhotosUI
import Vision
import ImageIO

struct ImageTextView: View {
    @EnvironmentObject private var store: Store
    @State private var photo: PhotosPickerItem?
    @State private var recognized = ""
    @State private var recognizing = false
    var body: some View {
        ToolCard(title: "Offline image text recognition", icon: "text.viewfinder") {
            PhotosPicker(selection: $photo, matching: .images) { Label("Choose screenshot or photo", systemImage: "photo") }.buttonStyle(.borderedProminent)
            if recognizing {
                HStack { ProgressView("Reading text…"); Spacer(); Button("Cancel") { photo = nil } }
            }
            TextEditor(text: $recognized).frame(minHeight: 280).scrollContentBackground(.hidden).accessibilityLabel("Recognized text")
            ViewThatFits {
                HStack { actions }
                VStack(alignment: .leading) { actions }
            }
            Text("Text recognition stays on this iPad. Review the result before using it. Selecting an iCloud image may download it through Photos.").font(.caption).foregroundStyle(.secondary)
        }.task(id: photo) { await recognize() }
    }
    @ViewBuilder private var actions: some View {
        Button("Copy text") { store.copy(recognized) }.buttonStyle(.bordered).disabled(recognized.isEmpty)
        Button("Save to shelf") { store.capture(recognized) }.buttonStyle(.bordered).disabled(recognized.isEmpty)
        ShareLink(item: recognized).buttonStyle(.bordered).disabled(recognized.isEmpty)
    }
    @MainActor private func recognize() async {
        guard let selected = photo else { recognizing = false; return }
        recognizing = true
        defer { if photo == selected { recognizing = false } }
        do {
            guard let data = try await selected.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
            try Task.checkCancellation()
            let worker = Task.detached(priority: .userInitiated) { try OCRService.recognize(data) }
            let output = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
            try Task.checkCancellation()
            guard photo == selected else { return }
            recognized = output
            if output.isEmpty { store.message = "No text found. Try a sharper image." }
        } catch is CancellationError { /* Selection changed or view closed. */ }
        catch { if !Task.isCancelled { store.message = "Could not read the image: \(error.localizedDescription)" } }
    }
}

enum ImageReadError: LocalizedError {
    case tooLarge
    var errorDescription: String? { "Choose an image smaller than 40 MB." }
}
enum OCRService {
    static func recognize(_ data: Data) throws -> String {
        guard data.count <= 40 * 1024 * 1024 else { throw ImageReadError.tooLarge }
        try Task.checkCancellation()
        return try autoreleasepool {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 4096,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
            try Task.checkCancellation()
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: image).perform([request])
            try Task.checkCancellation()
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }
    }
}
