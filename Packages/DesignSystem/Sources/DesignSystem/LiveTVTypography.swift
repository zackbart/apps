import SwiftUI

/// Typography ramp for the low-key "Marquee" design. Serif (New York) display
/// for hero titles, channel numbers, and shelf labels — light weights, italic
/// accents. Chrome and captions are tracked-out uppercase sans; anything
/// time-shaped keeps monospaced digits so columns align.
public enum LiveTVTypography {
    /// Display-weight headline — channel splash channel name, hero titles.
    /// Light serif: the signature of the design.
    public static let display: Font = .system(size: 64, weight: .light, design: .serif)

    /// The big Home-hero title. Larger than `display`, same voice.
    public static let heroDisplay: Font = .system(size: 84, weight: .light, design: .serif)

    /// Playbill now-playing panel title.
    public static let playbillTitle: Font = .system(size: 60, weight: .light, design: .serif)

    /// Serif-italic channel number — the marquee signature ("7", "21").
    public static let serifChannelNumber: Font = .system(size: 32, weight: .light, design: .serif).italic()

    /// Serif-italic shelf / section label ("On Now", "Latest").
    public static let shelfLabel: Font = .system(size: 32, weight: .regular, design: .serif).italic()

    /// Tracked-uppercase kicker line ("YOU WERE WATCHING · CHANNEL 7").
    /// Apply `.tracking(6)` (or similar) and `.textCase(.uppercase)` at the
    /// usage site — Font can't carry tracking.
    public static let kicker: Font = .system(size: 21, weight: .semibold)

    /// Strong title — section headers, error-card title.
    public static let strongTitle: Font = .title2.weight(.bold)

    /// Time labels in the EPG header and elapsed/remaining.
    public static let timeLabel: Font = .headline.monospacedDigit()

    /// Channel number in the guide column — monospaced so numbers align.
    public static let channelNumber: Font = .caption.monospacedDigit().weight(.semibold)

    /// Channel name in the guide channel column.
    public static let channelName: Font = .headline

    /// Program title in the splash and HUD.
    public static let programTitle: Font = .title3.weight(.semibold)

    /// Program time-range under the title.
    public static let programTime: Font = .subheadline.monospacedDigit()

    /// "LIVE" / "PREMIERE" / "REPEAT" tag pills.
    public static let tag: Font = .caption2.weight(.heavy)
}
