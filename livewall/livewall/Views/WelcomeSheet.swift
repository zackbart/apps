import SwiftUI

struct WelcomeSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            AppAmbientBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: Metrics.spacingL) {
                    Image(systemName: "sparkles.tv.fill")
                        .font(.system(size: 72, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)

                    VStack(spacing: Metrics.spacingS) {
                        Text("Welcome to LiveWall")
                            .font(.largeTitle.weight(.bold))

                        Text("Browse the gallery, preview on hover, and apply a living wallpaper to any of your displays.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: Metrics.spacingS) {
                        StatusPill(title: "Hover previews", systemImage: "play.circle")
                        StatusPill(title: "Multi-display", systemImage: "display.2")
                        StatusPill(title: "Battery-aware", systemImage: "bolt.badge.clock")
                    }

                    VStack(alignment: .leading, spacing: Metrics.spacingM) {
                        welcomeRow(
                            icon: "bolt.fill",
                            title: "Battery friendly",
                            detail: "Pauses automatically when you unplug or enable Low Power."
                        )
                        welcomeRow(
                            icon: "square.and.arrow.down",
                            title: "Import your own",
                            detail: "Drop any MP4 or MOV into the gallery window."
                        )
                        welcomeRow(
                            icon: "rectangle.on.rectangle",
                            title: "Multi-display",
                            detail: "Set a different wallpaper on each screen."
                        )
                    }
                    .padding(Metrics.spacingL)
                    .background {
                        RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: Metrics.radiusL, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            }
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Text("Let's Pick a Wallpaper")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, Metrics.spacingS)
                }
                .padding(.horizontal, Metrics.spacingXXL + Metrics.spacingM)
                .padding(.vertical, Metrics.spacingXXL)
                .frame(maxWidth: 440)
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
        .frame(minWidth: 480, minHeight: 580)
    }

    private func welcomeRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Metrics.spacingM) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
