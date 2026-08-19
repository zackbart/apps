import UIKit
import XCTest
@testable import MicroGains

@MainActor
final class OnboardingTests: XCTestCase {
    private func makeController(onFinish: @escaping () -> Void = {}) -> OnboardingViewController {
        let controller = OnboardingViewController(onFinish: onFinish)
        controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return controller
    }

    func testFourPagesAndNextWalksThroughThem() {
        let controller = makeController()
        XCTAssertEqual(controller.visiblePageIndex, 0)
        for expected in 1...3 {
            controller.advance()
            XCTAssertEqual(controller.visiblePageIndex, expected)
        }
    }

    func testFinishingWritesSettingsAndMarksOnboardingDone() {
        let defaults = UserDefaults(suiteName: "onboarding-test-\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.onboardingCompleted = false

        var finished = false
        let controller = makeController { finished = true }
        controller.advance()
        controller.advance()
        controller.advance()
        controller.advance() // the fourth call is Start

        XCTAssertTrue(finished, "the last page hands off to Home")
        XCTAssertTrue(AppCore.shared.settingsStore.onboardingCompleted)
        XCTAssertEqual(AppCore.shared.settings.timezone, TimeZone.current.identifier)
    }

    func testTheLiveSetsPerDayLineTracksTheControls() {
        var settings = AppSettings.default
        XCTAssertEqual(Controls.setsPerDayLine(settings), "About 5 sets a day")
        settings.intervalMinutes = 60
        XCTAssertEqual(Controls.setsPerDayLine(settings), "About 10 sets a day")
        settings.intervalMinutes = 240
        settings.activeEndMinute = settings.activeStartMinute + 240
        XCTAssertEqual(Controls.setsPerDayLine(settings), "About 1 set a day")
    }

    func testDifficultyExamplesComeFromTheLiveCatalog() {
        let catalog = Fixtures.bundledCatalog
        XCTAssertEqual(Controls.difficultyExample(.easy, catalog: catalog), "5 push-ups, 10 squats, 20 s plank")
        XCTAssertEqual(Controls.difficultyExample(.medium, catalog: catalog), "10 push-ups, 18 squats, 40 s plank")
        XCTAssertEqual(Controls.difficultyExample(.hard, catalog: catalog), "18 push-ups, 28 squats, 60 s plank")
    }

    func testCopyHasNoExclamationPoints() {
        // SPEC "Look": short, plain, verbs, no exclamation points.
        let controller = makeController()
        var labels: [String] = []
        func walk(_ view: UIView) {
            if let label = view as? UILabel, let text = label.text { labels.append(text) }
            if let button = view as? UIButton, let title = button.configuration?.title { labels.append(title) }
            view.subviews.forEach(walk)
        }
        walk(controller.view)
        XCTAssertFalse(labels.isEmpty)
        XCTAssertFalse(labels.contains { $0.contains("!") }, "found: \(labels.filter { $0.contains("!") })")
    }
}
