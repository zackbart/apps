import AppKit
import Combine

struct DisplayInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let localizedName: String
    let frame: CGRect
    let resolution: CGSize

    static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        lhs.id == rhs.id
    }
}

final class DisplayManager: ObservableObject {
    static let shared = DisplayManager()

    @Published var displays: [DisplayInfo] = []

    init() {
        refreshDisplays()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDisplays()
        }
    }

    func refreshDisplays() {
        var result: [DisplayInfo] = []
        for screen in NSScreen.screens {
            guard let displayID = screen.deviceDescription[.init("NSScreenNumber")] as? CGDirectDisplayID else {
                continue
            }

            let uuid = String(displayID)
            let name = screen.localizedName
            let frame = screen.frame
            let resolution = CGSize(
                width: frame.width * screen.backingScaleFactor,
                height: frame.height * screen.backingScaleFactor
            )

            result.append(DisplayInfo(
                id: uuid,
                name: name,
                localizedName: name,
                frame: frame,
                resolution: resolution
            ))
        }
        displays = result
    }
}
