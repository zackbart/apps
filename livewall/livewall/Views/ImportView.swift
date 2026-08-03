import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @State private var isShowingFilePicker = false
    @State private var isImporting = false
    @Environment(\.dismiss) private var dismiss

    private let catalog = WallpaperCatalog.shared
    private let engine = WallpaperEngine.shared

    var body: some View {
        ZStack {
            AppAmbientBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: Metrics.spacingL) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 56, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)

                    VStack(spacing: Metrics.spacingS) {
                        Text("Import a Wallpaper")
                            .font(.largeTitle.weight(.bold))

                        Text("Select an MP4 or MOV video file from your Mac and LiveWall will import it into your personal library.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                    }

                    HStack(spacing: Metrics.spacingS) {
                        StatusPill(title: "MP4 + MOV", systemImage: "film")
                        StatusPill(title: "Applies to all displays", systemImage: "display.2")
                        StatusPill(title: "Local-first", systemImage: "folder.fill")
                    }

                    Text("Tip: short seamless loops feel best as wallpapers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: Metrics.spacingM) {
                        if isImporting {
                            ProgressView("Importing…")
                                .controlSize(.regular)
                                .padding(.horizontal, Metrics.spacingL)
                                .padding(.vertical, Metrics.spacingM)
                                .glassEffect(.regular, in: .capsule)
                        } else {
                            Button {
                                isShowingFilePicker = true
                            } label: {
                                Label("Choose Video File", systemImage: "folder")
                                    .frame(minWidth: 200)
                            }
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                            .keyboardShortcut(.defaultAction)

                            Button("Cancel") {
                                dismiss()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .font(.callout)
                            .keyboardShortcut(.cancelAction)
                        }
                    }
                }
                .padding(Metrics.spacingXXL + Metrics.spacingM)
                .frame(maxWidth: 520)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.radiusXL, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: Metrics.radiusXL, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 12)
                }

                Spacer(minLength: 0)
            }
            .padding(Metrics.spacingXL)
        }
        .frame(minWidth: 520, minHeight: 440)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.mpeg4Movie, .quickTimeMovie, .video],
            allowsMultipleSelection: false
        ) { result in
            Task {
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        await importFile(url)
                    }
                case .failure(let error):
                    AppErrorPresenter.report(
                        title: "Couldn't Open File",
                        message: error.localizedDescription,
                        recoverySuggestion: "Try selecting a different file."
                    )
                }
            }
        }
    }

    private func importFile(_ url: URL) async {
        isImporting = true
        defer { isImporting = false }

        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if let wallpaper = await catalog.addLocalWallpaper(fileURL: url) {
            engine.apply(wallpaper, scope: .allDisplays)
            dismiss()
        }
    }
}
