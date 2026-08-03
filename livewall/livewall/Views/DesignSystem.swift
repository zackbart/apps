import SwiftUI

enum Metrics {
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 28

    static let radiusS: CGFloat = 10
    static let radiusM: CGFloat = 16
    static let radiusL: CGFloat = 22
    static let radiusXL: CGFloat = 28
}

enum Palette {
    static let activeGreenTint = Color.green.opacity(0.24)
}

struct StatusPill: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color? = nil

    var body: some View {
        Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, 7)
        .glassEffect(
            tint.map { .regular.tint($0.opacity(0.24)) } ?? .regular,
            in: .capsule
        )
    }
}

struct ActiveBadge: View {
    var text: String = "Active"
    var compact: Bool = false

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(compact ? .system(size: 10, weight: .semibold) : .caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, compact ? Metrics.spacingS : Metrics.spacingM)
            .padding(.vertical, compact ? 4 : 6)
            .glassEffect(.regular.tint(Palette.activeGreenTint), in: .capsule)
    }
}
