import Foundation
import CoreGraphics

/// Layout constants shared between `GuideModel` and `GuideView`.
public enum GuideLayout {
    /// Horizontal pixel density of the time grid: 8 points per minute.
    /// 12 hours of programming = 12 * 60 * 8 = 5760 pt of grid width.
    public static let pixelsPerMinute: CGFloat = 8

    /// Width of the sticky channel column on the left.
    public static let channelColumnWidth: CGFloat = 240

    /// Height of every channel row in the grid. Channel column cells and program
    /// rows must use this same height to stay aligned.
    public static let rowHeight: CGFloat = 100

    /// Height of the time-of-day header strip above the program grid.
    public static let timeHeaderHeight: CGFloat = 60

    /// Minimum width of a single program cell. Programs shorter than this number
    /// of minutes are widened so the title remains legible.
    public static let minimumProgramCellWidth: CGFloat = 60

    /// How far back from "now" we ask the server for programs, so that programs
    /// already in progress at the window start are included. Jellyfin's
    /// `MinStartDate` filter is "programs starting after this time", so we widen
    /// the lower bound to catch in-progress programs.
    public static let pastWindowSeconds: TimeInterval = 4 * 3600

    /// How far ahead of "now" the visible time window extends. The default 12h
    /// is fetched in a single request.
    public static let futureWindowSeconds: TimeInterval = 12 * 3600

    /// Convenience: convert a duration in seconds to grid points.
    public static func width(forDuration seconds: TimeInterval) -> CGFloat {
        max(minimumProgramCellWidth, CGFloat(seconds / 60.0) * pixelsPerMinute)
    }

    /// Convenience: convert an offset from `windowStart` (in seconds) to grid points.
    public static func offset(forSecondsSinceWindowStart seconds: TimeInterval) -> CGFloat {
        max(0, CGFloat(seconds / 60.0) * pixelsPerMinute)
    }
}
