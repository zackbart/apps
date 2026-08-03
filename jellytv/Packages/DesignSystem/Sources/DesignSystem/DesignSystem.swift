// DesignSystem module placeholder.
// Phase 2 adds shelf/card primitives, focus styles, colors, and typography here.

import SwiftUI
import JellyfinAPI

public enum DesignSystem {
    public static let version = "0.0.1"
}

public struct FocusedHomeItemKey: FocusedValueKey {
    public typealias Value = BaseItemDto
}

public extension FocusedValues {
    var focusedHomeItem: BaseItemDto? {
        get { self[FocusedHomeItemKey.self] }
        set { self[FocusedHomeItemKey.self] = newValue }
    }
}
