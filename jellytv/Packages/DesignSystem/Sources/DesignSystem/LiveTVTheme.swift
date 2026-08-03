import SwiftUI

/// Low-key "Marquee" palette: one warm-gray ink on near-black, nothing else.
/// The serif typography and the native focus lift carry the design — the only
/// chromatic color on screen is the desaturated brick-red live indicator.
/// Plain SwiftUI `Color` constants — no Asset Catalog indirection (tvOS-only
/// single theme, dark-mode-always).
public enum LiveTVTheme {
    /// The single ink. Warm gray-white (#E8E5DF) — everything legible is a
    /// tint of this.
    public static let ink = Color(red: 0.910, green: 0.898, blue: 0.875)

    /// Deepest background — full-bleed page background (#09090A).
    public static let background = Color(red: 0.035, green: 0.035, blue: 0.039)

    /// Slightly lifted surface for cards / overlays / selected rows.
    public static let surface = ink.opacity(0.06)

    /// Focus and emphasis accent — pale ink. Monochrome by design: focused
    /// borders and primary actions read as "lighter", never as a new color.
    public static let accent = ink.opacity(0.85)

    /// "On air" indicator — desaturated brick red (#B3473D), exclusively for
    /// the live dot, the now-line, and other "happening right now"
    /// affordances. The one color in the system.
    public static let live = Color(red: 0.702, green: 0.278, blue: 0.239)

    /// Body text.
    public static let text = ink

    /// De-emphasized text — captions, time-ranges, secondary metadata.
    public static let secondaryText = ink.opacity(0.45)

    /// Hairline divider between rows / sections.
    public static let divider = ink.opacity(0.16)
}
